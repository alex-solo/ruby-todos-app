require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def all_completed?(list)
    list[:todos].all? { |hash| hash[:completed] } && !list[:todos].empty?
  end

  def count_todos(array)
    left = array.select { |hash| hash[:completed] == true }.size
    total = array.size
    "#{left} / #{total}"
  end

  def list_class(list)
    "complete" if all_completed?(list)
  end

  def sort_lists(lists)
    hash = {}
    lists.each_with_index { |list, idx| hash[idx] = list }
    hash.to_a.sort_by { |list| all_completed?(list[1]) ? 1 : 0 }
  end

  def sort_todos(todos)
    hash = {}
    todos.each_with_index do |todo, idx|
      hash[idx] = todo
    end
    hash.to_a.sort_by do |todo|
      todo[1][:completed] ? 1 : 0
    end
  end
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.

def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  erb :edit_list, layout: :layout
end

post "/lists/:id" do
  @id = params[:id].to_i
  @list_name = params[:list_name]
  @list = session[:lists][@id]

  error = error_for_list_name(@list_name.strip)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][@id][:name] = @list_name
    session[:success] = "The list name has been edited."
    redirect "/lists/#{@id}"
  end
end

# Delete list from lists
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:delete] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params[:todo].strip
  @list = session[:lists][@list_id]
  @todos = @list[:todos]
  
  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo, completed: false }
    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
  
end

post "/lists/:list_id/todos/:index/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todos = @list[:todos]
  @todos.delete_at(params[:index].to_i)
  session[:success] = "The todo has been deleted"
  redirect "/lists/#{@list_id}"
end

# Toggle todo true/false (check and uncheck)
post "/lists/:list_id/todos/:index" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todos = @list[:todos]
  todo_id = params[:index].to_i
  is_completed = params[:completed] == "true"

  @todos[todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Check all todos as completed
post "/lists/:id/todos/check/all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @todos = @list[:todos]
  @todos.each { |todo| todo[:completed] = true }

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end