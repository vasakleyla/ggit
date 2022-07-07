module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

val run :
     context:(module CONTEXT)
  -> trust_system:Trust_system__Peer_trust.Make(Trust_system.Actions).t
  -> verifier:Verifier.t
  -> network:Mina_networking.t
  -> time_controller:Block_time.Controller.t
  -> collected_transitions:
       Transition_handler.Unprocessed_transition_cache.source list
  -> frontier:Transition_frontier.t
  -> network_transition_reader:
       ( [< `Block of
            ( [ `Time_received ] * unit Truth.true_t
            , [ `Genesis_state ] * unit Truth.true_t
            , [ `Proof ] * unit Truth.true_t
            , [ `Delta_block_chain ]
              * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
            , [ `Frontier_dependencies ] * unit Truth.false_t
            , [ `Staged_ledger_diff ] * unit Truth.false_t
            , [ `Protocol_versions ] * unit Truth.true_t )
            Mina_block.Validation.with_block
            Network_peer.Envelope.Incoming.t ]
       * [< `Valid_cb of Mina_net2.Validation_callback.t option ] )
       Pipe_lib.Strict_pipe.Reader.t
  -> producer_transition_reader:
       Transition_frontier.Breadcrumb.t Pipe_lib.Strict_pipe.Reader.t
  -> clear_reader:'a Pipe_lib.Strict_pipe.Reader.t
  -> verified_transition_writer:
       ( [> `Transition of Mina_block.Validated.t ]
         * [> `Source of [> `Catchup | `Gossip | `Internal ] ]
         * [> `Valid_cb of Mina_net2.Validation_callback.t option ]
       , 'b
       , unit )
       Pipe_lib.Strict_pipe.Writer.t
  -> unit