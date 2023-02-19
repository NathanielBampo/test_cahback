require 'sinatra/base'
require 'sequel'
require 'json'
require 'byebug'

class Success < Sinatra::Base
  DB = Sequel.sqlite('db/test.db')

  
  get '/' do
    @user_id = 2

    @operation_id = 18
    @write_off = 150

    erb :form_operation
  end

  post '/submit' do
    user = params['user_id'].to_i
    operation = params['operation'].to_i
    write_off = params['writeoff'].to_i

    user = DB[:user].where(id: user).first

    response = sum_operation(user, operation, write_off)

    response.to_json
  end

  private

  def sum_operation(user, operation, write_off)
    
  end
end
