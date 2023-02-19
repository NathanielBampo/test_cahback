require 'sinatra'
require 'sequel'
require 'json'
require 'byebug'

DB = Sequel.sqlite('db/test.db')

get '/' do
  @user_id = 1

  @operation_id = 13
  @write_off = 350

  erb :form_operation
end

post '/submit' do
  user = params['user_id'].to_i
  operation_id = params['operation'].to_i
  write_off = params['writeoff'].to_i

  user = DB[:user].where(id: user).first

  operation = DB[:operation].where(id: operation_id).update(write_off:)

  operation = DB[:operation].where(id: operation_id).first

  response = sum_operation(user, operation, write_off)

  response.to_json
end

  private

def sum_operation(user, operation, _write_off)
  message = messege(operation)
  sum_pay = check_sum(user, operation)

  {
    status: 200,
    message:,
    information: {
      user_id: user[:id],
      cashback_bonus: operation[:cashback].to_f,
      cashback_percent: "#{operation[:cashback_percent].to_f} %",
      discount: operation[:discount].to_f,
      discount_percent: "#{operation[:discount_percent].to_f}%",
      write_off: operation[:write_off].to_f,
      summ_pay: sum_pay
    }
  }
end

def messege(operation)
  if operation[:write_off] > operation[:allowed_write_off]
    'Недостаточно баллов для списания'
  else
    'Операция завершена'
  end
end

def check_sum(user, operation)
  allowed_write_off = operation[:allowed_write_off].to_f
  write_off = operation[:write_off].to_f
  sum = operation[:check_summ].to_f

  if allowed_write_off >= write_off
    operation.update(allowed_write_off: allowed_write_off - write_off)
    operation.update(check_summ: sum - write_off)
  elsif allowed_write_off <= write_off
    operation.update(check_summ: sum - allowed_write_off)
    operation.update(allowed_write_off: 0)
  else
    sum
  end
  operation[:check_summ].to_f
end
