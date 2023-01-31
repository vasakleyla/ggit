open Async
open Core_kernel
open Network_peer
open Network_peer.Rpc_intf

module type Gossip_net_intf = sig
  type t

  module Rpc_intf : Rpc_interface_intf

  val restart_helper : t -> unit

  val peers : t -> Peer.t list Deferred.t

  val bandwidth_info :
       t
    -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
       Deferred.Or_error.t

  val set_node_status : t -> string -> unit Deferred.Or_error.t

  val get_peer_node_status : t -> Peer.t -> string Deferred.Or_error.t

  val initial_peers : t -> Mina_net2.Multiaddr.t list

  val add_peer : t -> Peer.t -> is_seed:bool -> unit Deferred.Or_error.t

  val connection_gating : t -> Mina_net2.connection_gating Deferred.t

  val set_connection_gating :
    t -> Mina_net2.connection_gating -> Mina_net2.connection_gating Deferred.t

  val ban_peer : t -> Peer.t -> until:Time.t -> unit Deferred.t

  val banned_peers : t -> (Peer.t * Time.t) list

  val random_peers : t -> int -> Peer.t list Deferred.t

  val random_peers_except :
    t -> int -> except:Peer.Hash_set.t -> Peer.t list Deferred.t

  val query_peer' :
       ?how:Monad_sequence.how
    -> ?heartbeat_timeout:Time_ns.Span.t
    -> ?timeout:Time.Span.t
    -> t
    -> Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q list
    -> 'r list rpc_response Deferred.t

  val query_peer :
       ?heartbeat_timeout:Time_ns.Span.t
    -> ?timeout:Time.Span.t
    -> t
    -> Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r rpc_response Deferred.t

  val query_random_peers :
       t
    -> int
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r rpc_response Deferred.t List.t Deferred.t

  val broadcast_state :
    ?origin_topic:string -> t -> Message.state_msg -> unit Deferred.t

  val broadcast_transaction_pool_diff :
       ?origin_topic:string
    -> t
    -> Message.transaction_pool_diff_msg
    -> unit Deferred.t

  val broadcast_snark_pool_diff :
    ?origin_topic:string -> t -> Message.snark_pool_diff_msg -> unit Deferred.t

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t
end
