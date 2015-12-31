class CommentNotificationMailer < ApplicationMailer
  def email_notification(comment)
    @comment = comment


    bcc = @comment.proposal.event.participants.map do |participant|
      if participant.should_be_notified? && participant.did_not_make_comment?(@comment)
        participant.person.email
      end
    end.compact

    if bcc.any?
      mail_markdown(bcc: bcc,
                    from: @comment.proposal.event.contact_email,
                    subject: "A comment has been posted")
    end
  end
end

