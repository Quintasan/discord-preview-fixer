# frozen_string_literal: true

require_relative 'message'

# Retention policy. Past the window a message pair is forgotten, not deleted
# from Discord, so pruning needs no bot, no channel lookup, and no gateway
# connection — it runs before the bot is online.
class Pruner
  def self.run(older_than:)
    Message.prune(older_than:)
  end
end
