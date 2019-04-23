require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
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

  def sort_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}
    lists.each_with_index do |list, index|
      if all_completed?(list)
        complete_lists[list] = index
      else
        incomplete_lists[list] = index
      end
    end
      incomplete_lists.each { |list, index| yield list, index }
      complete_lists.each { |list, index| yield list, index }
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}
    todos.each_with_index do |todo, index|
      if todo[:completed]
        complete_todos[todo] = index
      else
        incomplete_todos[todo] = index
      end
    end
    incomplete_todos.each { |todo, index| yield todo, index }
    complete_todos.each { |todo, index| yield todo, index }
  end
end

def load_list(index)
  list = session[:lists].find { |list| list[:id] == index }
  return list if list
  
  session[:error] = "The list was not found"
  redirect "/lists"
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

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

def next_list_id(lists)
  max = lists.map { |list| list[:id] }.max || 0
  max + 1
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    lists = session[:lists]
    lists << { id: next_list_id(lists), name: list_name, todos: [] }

    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id" do
  id = params[:id].to_i
  @list = load_list(id)
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  @id = params[:id].to_i
  @list = load_list(@id)
  erb :edit_list, layout: :layout
end

post "/lists/:id" do
  @id = params[:id].to_i
  @list_name = params[:list_name]
  @list = load_list(@id)

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
  session[:lists].delete_if { |list| list[:id] == id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:delete] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params[:todo].strip
  @list = load_list(@list_id)
  @todos = @list[:todos]
  
  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@todos)
    @list[:todos] << { id: id, name: todo, completed: false }
    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
  
end

# Delete a todo from a list
post "/lists/:list_id/todos/:index/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @todos = @list[:todos]
  @todos.reject! { |todo| todo[:id] == params[:index].to_i }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted"
    redirect "/lists/#{@list_id}"
  end
end

# Toggle todo true/false (check and uncheck)
post "/lists/:list_id/todos/:index" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @list[:todos]
  todo_id = params[:index].to_i
  is_completed = params[:completed] == "true"

  todo = @todos.find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Check all todos as completed
post "/lists/:id/todos/check/all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @todos = @list[:todos]
  @todos.each { |todo| todo[:completed] = true }

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end