FactoryBot.define do
  factory :faq do
    sequence(:question) { |n| "Question #{n}?" }
    sequence(:answer) { |n| "Answer #{n}." }
    sequence(:position) { |n| n - 1 }
  end
end
