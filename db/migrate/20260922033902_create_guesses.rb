class CreateGuesses < ActiveRecord::Migration[8.1]
  def change
    create_table :guesses do |t|
      # index: false -- the composite unique index below leads with birb_id and
      # serves every birb-scoped lookup, so a second index here is dead weight.
      t.references :birb, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      # Scale 6 is ~10cm, far finer than anyone places a pin by hand, and the
      # conventional choice. 10 digits leaves 4 before the point, enough for 180.
      t.decimal :latitude,  precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false

      t.timestamps
    end

    # One guess per player per photo, and it is final. This lives in the
    # database rather than only in a validation because it is the rule the
    # reveal depends on: guessing is what earns you the sight of everyone
    # else's pins, so a second guess would be a way to look before committing.
    add_index :guesses, [ :birb_id, :user_id ], unique: true
  end
end
