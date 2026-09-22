class CreateBirbs < ActiveRecord::Migration[8.1]
  def change
    create_table :birbs do |t|
      # Doubles as the image's alt text, so it is not optional -- a photo with
      # no text equivalent is an accessibility hole, not a missing nicety.
      t.string :caption, null: false
      # The admin who posted it. Nothing reads this yet; it is the only record
      # of provenance, and it is one column.
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # The gallery is ordered newest first. Postgres reads a btree backwards
    # perfectly well, so an ascending index serves a descending sort.
    add_index :birbs, :created_at
  end
end
