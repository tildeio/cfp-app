class Participant < ActiveRecord::Base
  belongs_to :event
  belongs_to :person

  scope :for_event, -> (event) { where(event: event) }
  scope :recent, -> { order('created_at DESC') }

  scope :organizer, -> { where(role: 'organizer') }
  scope :reviewer, -> { where(role: ['reviewer', 'organizer']) }


  validates :person, :event, :role, presence: true
  validates :person_id, uniqueness: {scope: :event_id}


  def comment_notifications
    if notifications
      "\u2713"
    else
      "X"
    end
  end

  def should_be_notified?
    notifications
  end

  def did_not_make_comment?(comment)
    comment.person_id != person_id
  end
end


# == Schema Information
#
# Table name: participants
#
#  id            :integer          not null, primary key
#  event_id      :integer
#  person_id     :integer
#  role          :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  notifications :boolean          default(TRUE)
#
# Indexes
#
#  index_participants_on_event_id   (event_id)
#  index_participants_on_person_id  (person_id)
#
