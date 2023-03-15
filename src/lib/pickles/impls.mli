open Pickles_types

module Wrap_impl : module type of Kimchi_backend.Snarky.Wrap

module Step : sig
  module Impl : module type of Kimchi_backend.Snarky.Step

  include module type of Impl

  module Verification_key = Backend.Tick.Verification_key
  module Proving_key = Backend.Tick.Proving_key

  module Digest : module type of Import.Digest.Make (Impl)

  module Challenge : module type of Import.Challenge.Make (Impl)

  module Keypair : sig
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    val generate : prev_challenges:int -> Impl.Constraint_system.t -> t
  end

  module Other_field : sig
    type t = Field.t * Boolean.var

    module Constant = Backend.Tock.Field

    val typ_unchecked : (t, Constant.t) Typ.t

    val typ :
      ( t
      , Constant.t
      , Impl.field
      , Impl.field_var
      , Impl.run_state )
      Snarky_backendless.Typ.t
  end

  val input :
       proofs_verified:'a Pickles_types.Nat.t
    -> wrap_rounds:'b Pickles_types.Nat.t
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> ( ( ( ( Impl.Field.t
             , Impl.Field.t Composition_types.Scalar_challenge.t
             , Other_field.t Pickles_types.Shifted_value.Type2.t
             , ( Other_field.t Pickles_types.Shifted_value.Type2.t
               , Impl.field_var Snarky_backendless.Snark_intf.Boolean0.t )
               Pickles_types.Plonk_types.Opt.t
             , ( Impl.Field.t Composition_types.Scalar_challenge.t
                 Pickles_types.Hlist0.Id.t
                 Composition_types.Step.Proof_state.Deferred_values.Plonk
                 .In_circuit
                 .Lookup
                 .t
               , Impl.field_var Snarky_backendless.Snark_intf.Boolean0.t )
               Pickles_types.Plonk_types.Opt.t
             , ( Impl.field_var Kimchi_backend_common.Scalar_challenge.t
                 Composition_types.Bulletproof_challenge.t
               , 'b )
               Pickles_types.Vector.t
               Pickles_types.Hlist0.Id.t
             , Impl.field_var
             , Impl.field_var Snarky_backendless.Snark_intf.Boolean0.t )
             Composition_types.Step.Proof_state.Per_proof.In_circuit.t
           , 'a )
           Pickles_types.Vector.t
         , Impl.field_var Pickles_types.Hlist0.Id.t
         , (Impl.field_var, 'a) Pickles_types.Vector.t Pickles_types.Hlist0.Id.t
         )
         Import.Types.Step.Statement.t
       , ( ( ( Challenge.Constant.t
             , Challenge.Constant.t Composition_types.Scalar_challenge.t
             , Other_field.Constant.t Pickles_types.Shifted_value.Type2.t
             , Other_field.Constant.t Pickles_types.Shifted_value.Type2.t option
             , Challenge.Constant.t Composition_types.Scalar_challenge.t
               Composition_types.Step.Proof_state.Deferred_values.Plonk
               .In_circuit
               .Lookup
               .t
               option
             , ( Limb_vector.Challenge.Constant.t
                 Kimchi_backend_common.Scalar_challenge.t
                 Composition_types.Bulletproof_challenge.t
               , 'b )
               Pickles_types.Vector.t
               Pickles_types.Hlist0.Id.t
             , ( Limb_vector.Constant.Hex64.t
               , Composition_types.Digest.Limbs.n )
               Pickles_types.Vector.vec
             , bool )
             Composition_types.Step.Proof_state.Per_proof.In_circuit.t
           , 'a )
           Pickles_types.Vector.t
         , ( Limb_vector.Constant.Hex64.t
           , Composition_types.Digest.Limbs.n )
           Pickles_types.Vector.vec
           Pickles_types.Hlist0.Id.t
         , ( ( Limb_vector.Constant.Hex64.t
             , Composition_types.Digest.Limbs.n )
             Pickles_types.Vector.vec
           , 'a )
           Pickles_types.Vector.t
           Pickles_types.Hlist0.Id.t )
         Import.Types.Step.Statement.t
       , Impl.field
       , Impl.field_var
       , Impl.run_state )
       Import.Spec.ETyp.t
end

module Wrap : sig
  module Impl : module type of Kimchi_backend.Snarky.Wrap

  include module type of Impl

  module Challenge : module type of Import.Challenge.Make (Impl)

  module Digest : module type of Import.Digest.Make (Impl)

  module Wrap_field = Backend.Tock.Field
  module Step_field = Backend.Tick.Field
  module Verification_key = Backend.Tock.Verification_key
  module Proving_key = Backend.Tock.Proving_key

  module Keypair : sig
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    val generate : prev_challenges:int -> Impl.Constraint_system.t -> t
  end

  module Other_field : sig
    type t = Field.t

    module Constant = Backend.Tick.Field

    val typ_unchecked : (Impl.Field.t, Backend.Tick.Field.t) Impl.Typ.t

    val typ :
      ( Impl.Field.t
      , Kimchi_backend.Snarky.Step.Field.Constant.t
      , Impl.Field.Constant.t
      , Impl.field_var
      , Impl.run_state )
      Snarky_backendless.Typ.t
  end

  val input :
       unit
    -> ( ( Impl.Field.t
         , Impl.Field.t Composition_types.Scalar_challenge.t
         , Impl.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Impl.Field.t Pickles_types.Shifted_value.Type1.t
           , Impl.field_var Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Plonk_types.Opt.t
         , ( Impl.Field.t Composition_types.Scalar_challenge.t
             Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
             .Lookup
             .t
           , Impl.field_var Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Plonk_types.Opt.t
         , Impl.Boolean.var
         , Impl.field_var
         , Impl.field_var
         , Impl.field_var
         , ( Impl.field_var Kimchi_backend_common.Scalar_challenge.t
             Composition_types.Bulletproof_challenge.t
           , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
           Pickles_types.Vector.t
           Pickles_types.Hlist0.Id.t
         , Impl.field_var )
         Import.Types.Wrap.Statement.In_circuit.t
       , ( Limb_vector.Challenge.Constant.t
         , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
         , Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
         , Other_field.Constant.t Pickles_types.Shifted_value.Type1.t option
         , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
           Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
           .Lookup
           .t
           option
         , bool
         , ( Limb_vector.Constant.Hex64.t
           , Composition_types.Digest.Limbs.n )
           Pickles_types.Vector.vec
         , ( Limb_vector.Constant.Hex64.t
           , Composition_types.Digest.Limbs.n )
           Pickles_types.Vector.vec
         , ( Limb_vector.Constant.Hex64.t
           , Composition_types.Digest.Limbs.n )
           Pickles_types.Vector.vec
         , ( Limb_vector.Challenge.Constant.t
             Kimchi_backend_common.Scalar_challenge.t
             Composition_types.Bulletproof_challenge.t
           , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
           Pickles_types.Vector.t
           Pickles_types.Hlist0.Id.t
         , Composition_types.Branch_data.t )
         Import.Types.Wrap.Statement.In_circuit.t
       , Wrap_impl.field
       , Wrap_impl.field_var
       , Wrap_impl.run_state )
       Import.Spec.ETyp.t
end
