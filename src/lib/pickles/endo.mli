(** Curves used by the inductive proof system might support optimisations for the multi scalar
    multiplications. It is the case for instance for Pallas and Vesta as described
    in the {{ https://eprint.iacr.org/2019/1021.pdf } Halo paper }.

    This module provides a generic interface and abstract it with the Tick and
    Tock curves used in Pickles.
    For a more detailed description, the reader is invited to have a look at the
    {{ https://eprint.iacr.org/2019/1021.pdf } Halo paper }.
*)

(** [Step_inner_curve] contains the endo coefficients used by the step proof system *)
module Step_inner_curve : sig
  val base : Backend.Tick.Field.t

  val scalar : Backend.Tock.Field.t

  val to_field :
       Import.Challenge.Constant.t Import.Scalar_challenge.t
    -> Backend.Tock.Field.t
end

(** [Wrap_inner_curve] contains the endo coefficients used by the wrap proof system *)
module Wrap_inner_curve : sig
  val base : Backend.Tock.Field.t

  val scalar : Backend.Tick.Field.t

  val to_field :
       Import.Challenge.Constant.t Import.Scalar_challenge.t
    -> Backend.Tick.Field.t
end
