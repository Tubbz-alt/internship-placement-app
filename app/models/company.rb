class Company < ApplicationRecord
  DEFAULT_SLOTS = 1

  belongs_to :classroom
  has_many :rankings
  has_many :students, through: :rankings
  has_many :interviews, dependent: :destroy
  has_one :company_survey, dependent: :destroy

  validates :name, presence: true
  validates :slots, numericality: { integer_only: true, greater_than: 0 }

  scope :live, -> { where("redirect_to is NULL") }

  def feedback_count
    interviews.select(&:has_feedback?).length
  end

  def done_at
    interviews.max_by { |i| i.done_at }.done_at
  end

  def interviews_complete?
    interviews.all?(&:has_feedback?)
  end

  def survey_complete?
    company_survey != nil
  end
end
