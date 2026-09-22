class GuessesController < ApplicationController
  after_action :verify_authorized

  def create
    @birb = Birb.find(params[:birb_id])
    # Built off Current.user, so the player the guess belongs to is never
    # something the browser gets to say.
    @guess = Current.user.guesses.new(birb: @birb, **guess_params.to_h.symbolize_keys)
    authorize @guess

    if @guess.save
      redirect_to @birb, notice: "Guess locked in. Here is everyone else."
    else
      redirect_to @birb, alert: @guess.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotUnique
    # Two tabs submitting at once both pass the uniqueness validation and then
    # collide at the index. Their guess did land, once, so send them to it.
    redirect_to @birb, notice: "You have already guessed on this birb."
  end

  private
    def guess_params
      params.expect(guess: [ :latitude, :longitude ])
    end
end
