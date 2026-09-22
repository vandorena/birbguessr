class CreateLoginCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :login_codes do |t|
      t.references :user, null: false, foreign_key: true

      # bcrypt digest of the six-digit code the person types in.
      t.string :code_digest, null: false
      # SHA256 digest of the high-entropy token embedded in the magic link.
      # SHA256 rather than bcrypt because the token is already 190+ bits --
      # it is not guessable, so there is nothing for a slow hash to buy.
      t.string :link_token_digest, null: false
      # bcrypt digest of a cookie set in the browser that asked for the code.
      t.string :browser_token_digest, null: false

      t.integer :attempts, null: false, default: 0
      t.datetime :used_at
      t.inet :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :login_codes, :link_token_digest, unique: true
    add_index :login_codes, [ :user_id, :used_at, :created_at ]
  end
end
