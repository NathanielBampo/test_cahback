require 'sinatra'
require 'sequel'
require 'json'
require 'byebug'

DB = Sequel.sqlite('db/test.db')

get '/' do
  @user_id = 1

  @positions = [
    {
      id: 2,
      price: 100,
      quantity: 3
    },
    {
      id: 3,
      price: 50,
      quantity: 2
    },
    {
      id: 4,
      price: 40,
      quantity: 1
    }
  ]

  erb :form
end

post '/operation' do
  user_id = params['user_id']
  user = DB[:user].where(id: user_id).first

  positions = JSON.parse(params['positions'])

  response = process_operation(user, positions)

  response.to_json
end

  private

def process_operation(user, positions)
  total_amount = calculate_sum(positions)
  loyalty_level = get_loyalty_level(user)

  cashback_loaly = get_cashback_by_loaly(loyalty_level, user, percent_cashback = 0)
  discount_loyalty = get_discount_persent_by_loyalty(loyalty_level, user, discount_percent = 0)

  sum = sum(positions, discount_loyalty, sum = 0)
  allowed_summ = get_allowed_summ(positions, sum, allowed_summ = 0)

  cashback = cashback(positions, cashback_loaly, cashback = 0)
  cashback_percent = cashback / (total_amount.to_f / 100)

  discount = total_amount - sum
  discount_value_percent = discount / (total_amount.to_f / 100)

  new_positions = add_field_position(positions, discount_loyalty, discount)
  write_off = allowed_write_off(allowed_summ, user)

  operation = save_operation(user, cashback, cashback_percent, discount, discount_value_percent, sum, write_off)

  status 200

  {
    status: 200,
    user: {
      id: user[:id],
      template_id: user[:template_id],
      name: user[:name],
      bonus: user[:bonus].to_i
    },
    operation_id: operation,
    summ: sum,
    positions: new_positions,
    discount: {
      summ: discount,
      value: "#{discount_value_percent.ceil(2)} %"
    },
    cashback: {
      existed_summ: user[:bonus].to_i,
      allowed_summ:,
      value: "#{cashback_percent.round(2)} %",
      will_add: nil
    }
  }
end

# Доступно к списанию с бьнусных баллов
def get_allowed_summ(positions, sum, allowed_summ = 0)
  positions.each do |product|
    type_desc = DB[:product].where(id: product['id']).first

    allowed_summ = sum - (product['price'] * product['quantity']).to_f if type_desc[:type] = 'noloyalty'
  end
  allowed_summ
end

# Общая сумма
def calculate_sum(positions)
  positions.inject(0) { |sum, position| sum + position['price'] * position['quantity'] }
end

# Уровень лояльности Пользователя
def get_loyalty_level(user)
  template_id = DB[:user].where(id: user[:id]).first[:template_id]
  loyalty_level = DB[:template].where(id: template_id).first[:name]
end

# Кэшбэк от уровня лояльности
def get_cashback_by_loaly(loyalty_level, user, percent_cashback = 0)
  template_user_id = user[:template_id]

  case loyalty_level
  when 'Bronze' then percent_cashback += DB[:template].where(id: template_user_id).first[:cashback]
  when 'Silver' then percent_cashback += DB[:template].where(id: template_user_id).first[:cashback]
  end
  percent_cashback
end

# Скидка от уровня лояльности
def get_discount_persent_by_loyalty(loyalty_level, user, discount_percent = 0)
  template_id = user[:template_id]

  case loyalty_level
  when 'Silver' then discount_percent += DB[:template].where(id: template_id).first[:discount]
  when 'Gold' then discount_percent += DB[:template].where(id: template_id).first[:discount]
  end
  discount_percent
end

# Сумма с учётом скидок
def sum(positions, discount_loyalty, sum = 0)
  positions.each do |product|
    type_desc = DB[:product].where(id: product['id']).first

    case type_desc[:type]
    when 'discount'
      discount_all = type_desc[:value].to_i + discount_loyalty
      discount = ((product['price'] * product['quantity']).to_f / 100) * discount_all
      sum += (product['price'] * product['quantity']).to_f - discount
    when 'increased_cashback'
      discount = ((product['price'] * product['quantity']).to_f / 100) * discount_loyalty
      sum += (product['price'] * product['quantity']).to_f - discount
    when 'noloyalty'
      sum += (product['price'] * product['quantity']).to_f
    end
  end
  sum
end

# Расчет кэшбэка
def cashback(positions, cashback_loaly, cashback = 0)
  positions.each do |product|
    type_desc = DB[:product].where(id: product['id']).first

    case type_desc[:type]
    when 'increased_cashback'
      cashback += ((product['price'] * product['quantity']).to_f / 100) * (type_desc[:value].to_i + cashback_loaly)
    when 'discount'
      cashback += ((product['price'] * product['quantity']).to_f / 100) * cashback_loaly
    end
  end
  cashback
end

# Добавление новых полей в positions
def add_field_position(positions, discount_loyalty, discount)
  positions.map do |position|
    product = DB[:product].where(id: position['id']).first

    if product[:type] == 'increased_cashback'
      position[:type] = product[:type]
      position[:value] = product[:value]
      position[:type_desc] = "Дополнительный кэшбек #{position[:value]} %"
      position[:discount_percent] = discount_loyalty
      position[:discount_summ] = ((position['price'] * position['quantity']).to_f / 100) * discount_loyalty
    elsif product[:type] == 'discount'
      position[:type] = product[:type]
      position[:value] = product[:value]
      position[:type_desc] = "Дополнительная скидка #{position[:value]}%"
      position[:discount_percent] = discount_loyalty + product[:value].to_i
      position[:discount_summ] = discount
    else
      position[:type] = product[:type]
      position[:value] = product[:value]
      position[:type_desc] = 'Не участвует в системе лояльности'
      position[:discount_percent] = 0.0
      position[:discount_summ] = 0.0
    end
  end
  positions
end

def allowed_write_off(allowed_summ, user)
  return unless user[:bonus].to_i >= allowed_summ

  allowed_summ
end

# Сохранение операции и получени ID
def save_operation(user, cashback, cashback_percent, discount, discount_value_percent, sum, write_off)
  operations_table = DB[:operation]

  operation = {
    user_id: user[:id],
    cashback:,
    cashback_percent: cashback_percent.to_f,
    discount:,
    discount_percent: discount_value_percent.ceil(2),
    write_off: nil,
    check_summ: sum,
    done: nil,
    allowed_write_off: write_off
  }

  operations_table.insert(operation)
end
