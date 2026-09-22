class BirbsController < ApplicationController
  # Nothing calls allow_unauthenticated_access, so the Authentication concern's
  # default before_action covers every action here.
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
