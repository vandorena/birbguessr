class BirbsController < ApplicationController
  # The gallery is the landing page and renders to anyone. Every other action
  # here is still covered by the Authentication concern's default before_action
  # -- opening a birb signs you in first, and request_authentication remembers
  # which birb you were opening.
  allow_unauthenticated_access only: :index

  # Skipping the requirement is not the same as ignoring the cookie. The gallery
  # is public but not impersonal: it marks which birbs you have already guessed,
  # and it says whether you are signed in. Without this, Current.user is nil for
  # a signed-in visitor by the time index runs, and both of those go quietly
  # wrong -- the page renders, just as though nobody were there.
  before_action :resume_session, only: :index

  after_action :verify_authorized

  def index
    authorize Birb

    @birbs = Birb.recent.with_attached_photo
    # One query for the whole gallery rather than one per birb.
    @guessed_birb_ids = Guess.where(user: Current.user, birb: @birbs).pluck(:birb_id).to_set
  end

  def show
    @birb = Birb.find(params[:id])
    authorize @birb

    # Reveal owns the decision. @pins is [] until this player has guessed, and
    # the view has no way to render what it was not given.
    @reveal = Reveal.new(@birb, Current.user)
    @pins = @reveal.pins
  end

  def new
    @birb = Birb.new
    authorize @birb
  end

  def create
    @birb = Current.user.birbs.new(birb_params)
    authorize @birb

    if @birb.save
      redirect_to @birb, notice: "Birb posted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def birb_params
      params.expect(birb: [ :caption, :photo ])
    end
end
