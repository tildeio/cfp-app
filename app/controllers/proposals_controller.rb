class ProposalsController < ApplicationController
  before_action :require_event, except: :index
  before_action :require_user
  before_action :require_proposal, except: [ :index, :create, :new, :parse_edit_field ]
  before_action :require_invite_or_speaker, only: [:show]
  skip_before_action :require_invite_or_speaker, only: [:destroy]

  before_action :require_speaker, only: [:edit, :update]
  before_action :require_waitlisted_or_accepted_state, only: [:confirm]

  decorates_assigned :proposal

  def index
    proposals = current_user.proposals.decorate.group_by {|p| p.event}
    invitations = current_user.pending_invitations.decorate.group_by {|inv| inv.proposal.event}
    events = (proposals.keys | invitations.keys).uniq

    render locals: {
        events: events,
        proposals: proposals,
        invitations: invitations
    }
  end

  def new
    @proposal = Proposal.new(event: @event)
    @proposal.speakers.build(user: current_user)
  end

  def confirm

  end

  def set_confirmed
    @proposal.update(confirmed_at: DateTime.current,
                     confirmation_notes: params[:confirmation_notes])
    redirect_to confirm_event_proposal_url(slug: @proposal.event.slug, uuid: @proposal),
      flash: { success: 'Thank you for confirming your participation' }
  end

  def withdraw
    @proposal.withdraw unless @proposal.confirmed?
    flash[:info] = "Your withdrawal request has been submitted."
    redirect_to event_event_proposals_url(slug: @proposal.event.slug, uuid: @proposal)
  end

  def destroy
    @proposal.destroy
    flash[:info] = "Your proposal has been deleted."
    redirect_to event_proposals_url
  end

  def create
    @proposal = @event.proposals.new(proposal_params)
    speaker = @proposal.speakers[0]
    speaker.user_id = current_user.id
    speaker.event_id = @event.id

    if @proposal.save
      current_user.update_bio
      flash[:info] = setup_flash_message
      redirect_to event_proposal_url(event_slug: @event.slug, uuid: @proposal)
    else
      flash[:danger] = "There was a problem saving your proposal."
      render :new
    end
  end

  def show
    session[:event_id] = event.id

    render locals: {
      invitations: @proposal.invitations.not_accepted.decorate,
      event: @proposal.event.decorate
    }
  end

  def edit
  end

  def update
    if params[:confirm]
      @proposal.update(confirmed_at: DateTime.current)
      redirect_to event_event_proposals_url(slug: @event.slug, uuid: @proposal), flash: { success: "Thank you for confirming your participation" }
    elsif @proposal.update_and_send_notifications(proposal_params)
      redirect_to event_proposal_url(event_slug: @event.slug, uuid: @proposal)
    else
      flash[:danger] = "There was a problem saving your proposal."
      render :edit
    end
  end

  include ApplicationHelper
  def parse_edit_field
    respond_to do |format|
      format.js do
        render locals: {
          field_id: params[:id],
          text: markdown(params[:text])
        }
      end
    end
  end

  private

  def proposal_params
    params.require(:proposal).permit(:title, {tags: []}, :session_format_id, :track_id, :abstract, :details, :pitch, custom_fields: @event.custom_fields,
                                     comments_attributes: [:body, :proposal_id, :user_id],
                                     speakers_attributes: [:bio, :id])
  end

  def require_invite_or_speaker
    unless @proposal.has_speaker?(current_user) || @proposal.has_invited?(current_user)
      redirect_to root_path
      flash[:danger] = "You are not an invited speaker for the proposal you are trying to access."
    end
  end

  def require_speaker
    unless @proposal.has_speaker?(current_user)
      redirect_to root_path
      flash[:danger] = "You are not a listed speaker for the proposal you are trying to access."
    end
  end

  def setup_flash_message
    message = "Thank you! Your proposal has been submitted and may be reviewed at any time while the CFP is open.\n\n"
    message << "You are welcome to update your proposal or leave a comment at any time, just please be sure to preserve your anonymity.\n\n"

    if @event.closes_at
      message << "Expect a response regarding acceptance after the CFP closes on #{@event.closes_at.to_s(:long)}."
    end
  end

  def require_waitlisted_or_accepted_state
    unless @proposal.waitlisted? || @proposal.accepted?
      redirect_to event_url(@event.slug)
    end
  end
end
