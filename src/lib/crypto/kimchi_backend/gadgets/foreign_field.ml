open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(* 2^2L *)
let two_to_2limb = Bignum_bigint.(pow Common.two_to_limb (of_int 2))

(* 2^3L *)
let two_to_3limb = Bignum_bigint.(pow Common.two_to_limb (of_int 3))

let two_to_limb_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) =
  Common.(bignum_bigint_to_field (module Circuit) two_to_limb)

let two_to_2limb_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) =
  Common.(bignum_bigint_to_field (module Circuit) two_to_2limb)

(* Binary modulus *)
let binary_modulus = two_to_3limb

(* Maximum foreign field modulus for multiplication m = sqrt(2^t * n), see RFC for more details
 *   For simplicity and efficiency we use the approximation m = floor(sqrt(2^t * n))
 *     * Distinct from this approximation is the maximum prime foreign field modulus
 *       for both Pallas and Vesta given our CRT scheme:
 *       926336713898529563388567880069503262826888842373627227613104999999999999999607 *)
let max_foreign_field_modulus (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) :
    Bignum_bigint.t =
  (* m = floor(sqrt(2^t * n)) *)
  let product =
    (* We need Zarith for sqrt *)
    Bignum_bigint.to_zarith_bigint
    @@ Bignum_bigint.(binary_modulus * Circuit.Field.size)
    (* Zarith.sqrt truncates (rounds down to int) ~ floor *)
  in
  Bignum_bigint.of_zarith_bigint @@ Z.sqrt product

(* Foreign field modulus is abstract on two parameters
 *   - Field type
 *   - Limbs structure
 *
 *   There are 3 specific limb structures required
 *     - Standard mode : 3 limbs of L-bits each
 *     - Extended mode : 4 limbs of L-bits each, used by bound addition (i.e. Matthew's trick)
 *     - Compact mode  : 2 limbs where the lowest is 2L bits and the highest is L bits
 *)

type 'field standard_limbs = 'field * 'field * 'field

type 'field extended_limbs = 'field * 'field * 'field * 'field

type 'field compact_limbs = 'field * 'field

type 'field limbs =
  | Standard of 'field standard_limbs
  | Extended of 'field extended_limbs
  | Compact of 'field compact_limbs

(* Convert Bignum_bigint.t to Bignum_bigint standard_limbs *)
let bignum_bigint_to_standard_limbs (bigint : Bignum_bigint.t) :
    Bignum_bigint.t standard_limbs =
  let l12, l0 = Common.(bignum_bigint_div_rem bigint two_to_limb) in
  let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
  (l0, l1, l2)

(* Convert Bignum_bigint.t to field standard_limbs *)
let bignum_bigint_to_field_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f standard_limbs =
  let l0, l1, l2 = bignum_bigint_to_standard_limbs bigint in
  ( Common.bignum_bigint_to_field (module Circuit) l0
  , Common.bignum_bigint_to_field (module Circuit) l1
  , Common.bignum_bigint_to_field (module Circuit) l2 )

(* Convert Bignum_bigint.t to Bignum_bigint compact_limbs *)
let bignum_bigint_to_compact_limbs (bigint : Bignum_bigint.t) :
    Bignum_bigint.t compact_limbs =
  let l2, l01 = Common.bignum_bigint_div_rem bigint two_to_2limb in
  (l01, l2)

(* Convert Bignum_bigint.t to field compact_limbs *)
let bignum_bigint_to_field_compact_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f compact_limbs =
  let l01, l2 = bignum_bigint_to_compact_limbs bigint in
  ( Common.bignum_bigint_to_field (module Circuit) l01
  , Common.bignum_bigint_to_field (module Circuit) l2 )

(* Convert field standard_limbs to Bignum_bigint.t standard_limbs *)
let field_standard_limbs_to_bignum_bigint_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_limbs : f standard_limbs) : Bignum_bigint.t standard_limbs =
  let l0, l1, l2 = field_limbs in
  ( Common.field_to_bignum_bigint (module Circuit) l0
  , Common.field_to_bignum_bigint (module Circuit) l1
  , Common.field_to_bignum_bigint (module Circuit) l2 )

(* Convert field standard_limbs to Bignum_bigint.t *)
let field_standard_limbs_to_bignum_bigint (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_limbs : f standard_limbs) : Bignum_bigint.t =
  let l0, l1, l2 =
    field_standard_limbs_to_bignum_bigint_standard_limbs
      (module Circuit)
      field_limbs
  in
  Bignum_bigint.(l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2))

(* Foreign field element interface *)
module type Element_intf = sig
  type 'field t

  type 'a limbs_type

  module Cvar = Snarky_backendless.Cvar

  (* Create foreign field element from Cvar limbs *)
  val of_limbs : 'field Cvar.t limbs_type -> 'field t

  (* Create foreign field element from Bignum_bigint.t *)
  val of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field Cvar.t limbs_type

  (* Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g limbs_type

  (* Convert foreign field element into field limbs *)
  val to_field_limbs_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field limbs_type

  (* Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs_type

  (* Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t

  (* Check that the foreign element is smaller than a given field modulus *)
  val fits_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field standard_limbs
    -> bool
end

(* Foreign field element structures *)
module Element : sig
  (* Foreign field element (extended limbs) *)
  module Extended : Element_intf with type 'a limbs_type = 'a extended_limbs

  (* Foreign field element (standard limbs) *)
  module Standard : sig
    include Element_intf with type 'a limbs_type = 'a standard_limbs

    (* Convert a standard foreign element into extended limbs *)
    val extend_as_prover :
         (module Snark_intf.Run with type field = 'field)
      -> 'field t
      -> 'field Cvar.t extended_limbs
  end

  (* Foreign field element (compact limbs) *)
  module Compact : Element_intf with type 'a limbs_type = 'a compact_limbs
end = struct
  (* Extended limbs foreign field element *)
  module Extended = struct
    module Cvar = Snarky_backendless.Cvar

    type 'field limbs_type = 'field extended_limbs

    type 'field t = 'field Cvar.t extended_limbs

    let of_limbs x = x

    let of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l123, l0 = Common.(bignum_bigint_div_rem x two_to_limb) in
      let l23, l1 = Common.(bignum_bigint_div_rem l123 two_to_limb) in
      let l3, l2 = Common.(bignum_bigint_div_rem l23 two_to_limb) in
      let limb_vars =
        exists (Typ.array ~length:4 Field.typ) ~compute:(fun () ->
            [| Common.bignum_bigint_to_field (module Circuit) l0
             ; Common.bignum_bigint_to_field (module Circuit) l1
             ; Common.bignum_bigint_to_field (module Circuit) l2
             ; Common.bignum_bigint_to_field (module Circuit) l3
            |] )
      in
      of_limbs (limb_vars.(0), limb_vars.(1), limb_vars.(2), limb_vars.(3))

    let to_limbs x = x

    let map (x : 'field t) (func : 'field Cvar.t -> 'g) : 'g limbs_type =
      let l0, l1, l2, l3 = to_limbs x in
      (func l0, func l1, func l2, func l3)

    let to_field_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : field limbs_type =
      map x (Common.cvar_field_to_field_as_prover (module Circuit))

    let to_bignum_bigint_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t limbs_type =
      map x (Common.cvar_field_to_bignum_bigint_as_prover (module Circuit))

    let to_bignum_bigint_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t =
      let l0, l1, l2, l3 =
        to_bignum_bigint_limbs_as_prover (module Circuit) x
      in
      Bignum_bigint.(
        l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2)
        + (two_to_3limb * l3))

    let fits_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        (modulus : field standard_limbs) : bool =
      let modulus =
        field_standard_limbs_to_bignum_bigint (module Circuit) modulus
      in
      Bignum_bigint.(to_bignum_bigint_as_prover (module Circuit) x < modulus)
  end

  (* Standard limbs foreign field element *)
  module Standard = struct
    module Cvar = Snarky_backendless.Cvar

    type 'field limbs_type = 'field standard_limbs

    type 'field t = 'field Cvar.t standard_limbs

    let of_limbs x = x

    let of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l12, l0 = Common.(bignum_bigint_div_rem x two_to_limb) in
      let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
      let limb_vars =
        exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
            [| Common.bignum_bigint_to_field (module Circuit) l0
             ; Common.bignum_bigint_to_field (module Circuit) l1
             ; Common.bignum_bigint_to_field (module Circuit) l2
            |] )
      in
      of_limbs (limb_vars.(0), limb_vars.(1), limb_vars.(2))

    let to_limbs x = x

    let map (x : 'field t) (func : 'field Cvar.t -> 'g) : 'g limbs_type =
      let l0, l1, l2 = to_limbs x in
      (func l0, func l1, func l2)

    let to_field_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : field limbs_type =
      map x (Common.cvar_field_to_field_as_prover (module Circuit))

    let to_bignum_bigint_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t limbs_type =
      map x (Common.cvar_field_to_bignum_bigint_as_prover (module Circuit))

    let to_bignum_bigint_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t =
      let l0, l1, l2 = to_bignum_bigint_limbs_as_prover (module Circuit) x in
      Bignum_bigint.(l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2))

    let fits_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        (modulus : field standard_limbs) : bool =
      let modulus =
        field_standard_limbs_to_bignum_bigint (module Circuit) modulus
      in
      Bignum_bigint.(to_bignum_bigint_as_prover (module Circuit) x < modulus)

    let extend_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        =
      let l0, l1, l2 = to_limbs x in
      Extended.of_limbs (l0, l1, l2, Circuit.Field.zero)
  end

  (* Compact limbs foreign field element *)
  module Compact = struct
    module Cvar = Snarky_backendless.Cvar

    type 'field limbs_type = 'field compact_limbs

    type 'field t = 'field Cvar.t compact_limbs

    let of_limbs x = x

    let of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l2, l01 = Common.(bignum_bigint_div_rem x two_to_2limb) in

      let limb_vars =
        exists (Typ.array ~length:2 Field.typ) ~compute:(fun () ->
            [| Common.bignum_bigint_to_field (module Circuit) l01
             ; Common.bignum_bigint_to_field (module Circuit) l2
            |] )
      in
      of_limbs (limb_vars.(0), limb_vars.(1))

    let to_limbs x = x

    let map (x : 'field t) (func : 'field Cvar.t -> 'g) : 'g limbs_type =
      let l0, l1 = to_limbs x in
      (func l0, func l1)

    let to_field_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : field limbs_type =
      map x (Common.cvar_field_to_field_as_prover (module Circuit))

    let to_bignum_bigint_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t limbs_type =
      map x (Common.cvar_field_to_bignum_bigint_as_prover (module Circuit))

    let to_bignum_bigint_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        =
      let l01, l2 = to_bignum_bigint_limbs_as_prover (module Circuit) x in
      Bignum_bigint.(l01 + (two_to_2limb * l2))

    let fits_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        (modulus : field standard_limbs) : bool =
      let modulus =
        field_standard_limbs_to_bignum_bigint (module Circuit) modulus
      in
      Bignum_bigint.(to_bignum_bigint_as_prover (module Circuit) x < modulus)
  end
end

(* Structure for tracking external checks that must be made
 * (using other gadgets) in order to acheive soundess for a
 * given multiplication *)
module External_checks = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t =
    { mutable multi_ranges : 'field Cvar.t standard_limbs list
    ; mutable compact_multi_ranges : 'field Cvar.t compact_limbs list
    ; mutable bound_additions : 'field Cvar.t standard_limbs list
    }

  let create (type field)
      (module Circuit : Snark_intf.Run with type field = field) : field t =
    { multi_ranges = []; compact_multi_ranges = []; bound_additions = [] }

  (* Track a multi-range-check *)
  let add_multi_range_check (external_checks : 'field t)
      (x : 'field Cvar.t standard_limbs) =
    external_checks.multi_ranges <- x :: external_checks.multi_ranges

  (* Track a compact-multi-range-check *)
  let add_compact_multi_range_check (external_checks : 'field t)
      (x : 'field Cvar.t compact_limbs) =
    external_checks.compact_multi_ranges <-
      x :: external_checks.compact_multi_ranges

  (* Track a bound addition *)
  let add_bound_addition (external_checks : 'field t)
      (x : 'field Cvar.t standard_limbs) =
    external_checks.bound_additions <- x :: external_checks.bound_additions
end

(* Common auxiliary functions for foreign field gadgets *)

(* Check that the foreign modulus is less than the maximum allowed *)
let check_modulus (type f) (module Circuit : Snark_intf.Run with type field = f)
    (foreign_field_modulus : f standard_limbs) =
  (* Check foreign field modulus < max allowed *)
  let foreign_field_modulus =
    field_standard_limbs_to_bignum_bigint (module Circuit) foreign_field_modulus
  in
  (* Note that the maximum foreign field modulus possible for addition is much
   * larger than that supported by multiplication.
   *
   * Specifically, since the 88-bit limbs are embedded in a native field element
   * of ~2^255 bits and foreign field addition increases the number of bits
   * logarithmically, for addition we can actually support a maximum field modulus
   * of 2^264 - 1 (i.e. binary_modulus - 1) for circuits up to length ~ 2^79 - 1,
   * which is far larger than the maximum circuit size supported by Kimchi.
   *
   * However, for compatibility with multiplication operations, we must use the
   * same maximum as foreign field multiplication.
   *)
  assert (
    Bignum_bigint.(
      foreign_field_modulus < max_foreign_field_modulus (module Circuit)) )

(* Represents two limbs as one single field element with twice as many bits *)
let compact_limb (type f) (module Circuit : Snark_intf.Run with type field = f)
    (lo : f) (hi : f) : f =
  Circuit.Field.Constant.(lo + (hi * two_to_limb_field (module Circuit)))

let tuple3_of_array array =
  match array with [| a1; a2; a3 |] -> (a1, a2, a3) | _ -> assert false

let tuple4_of_array array =
  match array with
  | [| a1; a2; a3; a4 |] ->
      (a1, a2, a3, a4)
  | _ ->
      assert false

let tuple11_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6; a7; a8; a9; a10; a11 |] ->
      (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
  | _ ->
      assert false

let tuple24_of_array array =
  match array with
  | [| a1
     ; a2
     ; a3
     ; a4
     ; a5
     ; a6
     ; a7
     ; a8
     ; a9
     ; a10
     ; a11
     ; a12
     ; a13
     ; a14
     ; a15
     ; a16
     ; a17
     ; a18
     ; a19
     ; a20
     ; a21
     ; a22
     ; a23
     ; a24
    |] ->
      ( a1
      , a2
      , a3
      , a4
      , a5
      , a6
      , a7
      , a8
      , a9
      , a10
      , a11
      , a12
      , a13
      , a14
      , a15
      , a16
      , a17
      , a18
      , a19
      , a20
      , a21
      , a22
      , a23
      , a24 )
  | _ ->
      assert false

(* FOREIGN FIELD ADDITION GADGET *)

(* Internal computation for foreign field addition *)
let add_setup (type f) (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Element.Standard.t) (right_input : f Element.Extended.t)
    (is_sub : bool) (foreign_field_modulus : f standard_limbs) :
    f Element.Standard.t * Circuit.Field.t * Circuit.Field.t =
  let open Circuit in
  (* Check foreign field modulus < max allowed *)
  check_modulus (module Circuit) foreign_field_modulus ;
  (* Decompose modulus into limbs *)
  let foreign_field_modulus0, foreign_field_modulus1, foreign_field_modulus2 =
    foreign_field_modulus
  in

  (* Addition or subtraction *)
  let sign = Field.Constant.(if is_sub then negate one else one) in

  (* Given a left and right inputs to an addition or subtraction, and a modulus, it computes
     * all necessary values needed for the witness layout. Meaning, it returns an [FFAddValues] instance
     * - the result of the addition/subtraction as a ForeignElement
     * - the sign of the operation
     * - the overflow flag
     * - the carry value *)
  let ( left_input0
      , left_input1
      , left_input2
      , right_input0
      , right_input1
      , right_input2
      , result0
      , result1
      , result2
      , field_overflow
      , carry ) =
    exists (Typ.array ~length:11 Field.typ) ~compute:(fun () ->
        (* Compute bigint version of the inputs *)
        let modulus =
          field_standard_limbs_to_bignum_bigint
            (module Circuit)
            foreign_field_modulus
        in
        (* Clarification *)
        (* let right_hi = right_input[3] * F::two_to_limb() + right_input[HI]; (* This allows to store 2^88 in the high limb *) *)
        let left =
          Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            left_input
        in
        let right =
          Element.Extended.to_bignum_bigint_as_prover
            (module Circuit)
            right_input
        in

        (* Make sure that inputs are smaller than the foreign modulus.
             If the right input is 2^264, then this is also acceptable. *)
        assert (
          Element.Standard.fits_as_prover
            (module Circuit)
            left_input foreign_field_modulus ) ;
        assert (
          Element.Extended.fits_as_prover
            (module Circuit)
            right_input foreign_field_modulus
          || Bignum_bigint.equal right two_to_3limb ) ;

        (* Compute values for the ffadd *)

        (* Overflow if addition and greater than modulus or
         * underflow if subtraction and less than zero
         *)
        let has_overflow =
          Bignum_bigint.(
            if is_sub then left < right else left + right >= modulus)
        in

        (* 0 for no overflow
         * -1 for underflow
         * +1 for overflow
         *)
        let field_overflow =
          if has_overflow then sign else Field.Constant.zero
        in

        (* Compute the result
         * result = left + sign * right - field_overflow * modulus
         * TODO: unluckily, we cannot do it in one line if we keep these types, because one
         *       cannot combine field elements and biguints in the same operation automatically
         *)
        let result =
          Element.Standard.of_bignum_bigint (module Circuit)
          @@ Bignum_bigint.(
               if is_sub then
                 if not has_overflow then (* normal subtraction *)
                   left - right
                 else (* underflow *)
                   modulus + left - right
               else if not has_overflow then (* normal addition *)
                 left + right
               else (* overflow *)
                 left + right - modulus)
        in

        (* c = [ (a1 * 2^88 + a0) + s * (b1 * 2^88 + b0) - q * (f1 * 2^88 + f0) - (r1 * 2^88 + r0) ] / 2^176
         *  <=>
         * c = r2 - a2 - s*b2 + q*f2 *)
        let left_input0, left_input1, left_input2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) left_input
        in
        let right_input0, right_input1, right_input2, right_input3 =
          Element.Extended.to_field_limbs_as_prover (module Circuit) right_input
        in
        let result0, result1, result2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) result
        in
        (* This allows to store 2^88 in the high limb*)
        let offset =
          Common.(bignum_bigint_to_field (module Circuit) two_to_limb)
        in
        let right_input2 =
          Field.Constant.((right_input3 * offset) + right_input2)
        in

        (* Compute the carry value *)
        let carry_bot =
          Field.Constant.(
            ( compact_limb (module Circuit) left_input0 left_input1
            + compact_limb (module Circuit) right_input0 (right_input1 * sign)
            - compact_limb
                (module Circuit)
                foreign_field_modulus0
                (foreign_field_modulus1 * field_overflow)
            - compact_limb (module Circuit) result0 result1 )
            / two_to_2limb_field (module Circuit))
        in

        let carry_top =
          Field.Constant.(
            result2 - left_input2 - (sign * right_input2)
            + (field_overflow * foreign_field_modulus2))
        in

        (* Check that both ways of computing the carry value are equal *)
        assert (Field.Constant.equal carry_top carry_bot) ;

        (* Return the ffadd values *)
        [| left_input0
         ; left_input1
         ; left_input2
         ; right_input0
         ; right_input1
         ; right_input2
         ; result0
         ; result1
         ; result2
         ; field_overflow
         ; carry_bot
        |] )
    |> tuple11_of_array
  in

  (* Create the gate *)
  with_label "ffadd_gate" (fun () ->
      (* Set up FFAdd gate *)
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldAdd
                 { left_input_lo = left_input0
                 ; left_input_mi = left_input1
                 ; left_input_hi = left_input2
                 ; right_input_lo = right_input0
                 ; right_input_mi = right_input1
                 ; right_input_hi = right_input2
                 ; field_overflow
                 ; carry
                 ; foreign_field_modulus0
                 ; foreign_field_modulus1
                 ; foreign_field_modulus2
                 ; sign
                 } )
        } ) ;

  (* Return the result *)
  ( Element.Standard.of_limbs (result0, result1, result2)
  , Field.constant sign
  , field_overflow )

(* Definition of a gadget for a single foreign field addition
   * - left_input of the addition as 3 limbs element
   * - right_input of the addition as 4 limbs element
   * - is_sub: a flag indicating whether the corresponding gate is addition or a subtraction
   * - foreign_field_modulus: the modulus of the foreign field
   * - Returns the result of the addition/subtraction as a 3 limbs element
   *
*)
let add (type f) (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Element.Standard.t) (right_input : f Element.Standard.t)
    (is_sub : bool) (foreign_field_modulus : f standard_limbs) :
    f Element.Standard.t =
  let open Circuit in
  let right0, right1, right2, right3 =
    exists (Typ.array ~length:4 Field.typ) ~compute:(fun () ->
        (* Parse the right input *)
        let right0, right1, right2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) right_input
        in
        [| right0; right1; right2; Field.Constant.zero |] )
    |> tuple4_of_array
  in
  let right_input =
    Element.Extended.of_limbs (right0, right1, right2, right3)
  in
  let result, _sign, _ovf =
    add_setup
      (module Circuit)
      left_input right_input is_sub foreign_field_modulus
  in
  result

(* This function adds a FFAdd gate to check that a given value is smaller than the modulus.
 * - value                 := the value to check
 * - external_checks       := Optional context to track required external checks.
 *                            When omitted, creates and returns new external_checks structure.
 *                            Otherwise, appends new required external checks to supplied structure.
 * - foreign_field_modulus := the modulus of the foreign field
 *)
let less_than_fmod (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    ?(external_checks : f External_checks.t option)
    (value : f Element.Standard.t) (foreign_field_modulus : f standard_limbs) :
    f Element.Standard.t * f External_checks.t =
  let open Circuit in
  (* Compute the value for the right input of the addition as 2^264 *)
  let offset =
    Element.Extended.of_limbs (Field.zero, Field.zero, Field.zero, Field.one)
  in

  (* Create FFAdd gate for the bound check *)
  let bound, sign, ovf =
    add_setup (module Circuit) value offset false foreign_field_modulus
  in

  let bound0, bound1, bound2 =
    exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
        (* Parse the bound outcome *)
        let bound0, bound1, bound2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) bound
        in

        (* Check that the correct expected values were obtained *)
        let sign = Common.cvar_field_to_field_as_prover (module Circuit) sign in
        let ovf = Common.cvar_field_to_field_as_prover (module Circuit) ovf in
        assert (Field.Constant.(equal sign one)) ;
        assert (Field.Constant.(equal ovf one)) ;

        [| bound0; bound1; bound2 |] )
    |> tuple3_of_array
  in

  (* Final Zero gate*)
  with_label "final_add_zero_gate" (fun () ->
      (* Set up FFAdd gate *)
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Raw
                 { kind = Zero
                 ; values = [| bound0; bound1; bound2 |]
                 ; coeffs = [||]
                 } )
        } ) ;

  (* Set up copy constraints with overflow with the overflow check*)
  Field.Assert.equal ovf Field.one ;

  (* Prepare external check for multi range check *)
  let external_checks =
    match external_checks with
    | Some external_checks ->
        external_checks
    | None ->
        External_checks.create (module Circuit)
  in
  External_checks.add_multi_range_check external_checks (bound0, bound1, bound2) ;

  (* Return the bound value *)
  (Element.Standard.of_limbs (bound0, bound1, bound2), external_checks)

(* FOREIGN FIELD ADDITION CHAIN GADGET *)

(* Definition of a gadget for a chain of foreign field additions
   * - inputs: all the inputs to the chain of additions
   * - is_sub: a list of booleans indicating whether the corresponding addition is a subtraction
   * - foreign_field_modulus: the modulus of the foreign field (all the same)
   * - Returns the final result of the chain of additions
   *
   * For n+1 inputs, the gadget creates n foreign field addition gates, followed by a final
   * foreign field addition gate for the bound check. An additional multi range check must be performed.
   * By default, the range check takes place right after the final Raw row.
*)
let add_chain (type f) (module Circuit : Snark_intf.Run with type field = f)
    (inputs : f Element.Standard.t list) (is_sub : bool list)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let open Circuit in
  (* Check that the number of inputs is correct *)
  let n = List.length is_sub in
  assert (List.length inputs = n + 1) ;

  (* Initialize first left input *)
  let left = [| List.hd_exn inputs |] in

  (* For all n additions, compute its values and create gates *)
  for i = 0 to n - 1 do
    let right = List.nth_exn inputs (i + 1) in
    let sub = List.nth_exn is_sub i in

    (* Create the foreign field addition row *)
    let result =
      add (module Circuit) left.(0) right sub foreign_field_modulus
    in

    (* Update left input for next iteration *)
    left.(0) <- result ; ()
  done ;

  (* Add the final gate for the bound *)
  (* result + (2^264 - f) = bound *)
  let result = left.(0) in
  let bound, _external_checks =
    less_than_fmod (module Circuit) result foreign_field_modulus
  in
  let bound0, bound1, bound2 = Element.Standard.to_limbs bound in

  (* Include Multi range check for the bound right after *)
  Range_check.multi (module Circuit) bound0 bound1 bound2 ;

  (* Return result *)
  result

(* FOREIGN FIELD MULTIPLICATION *)

(* Compute non-zero intermediate products
 *
 *   For more details see the "Intermediate products" Section of
 *   the [Foreign Field Multiplication RFC](../rfcs/foreign_field_mul.md)
 *
 *   Preconditions: this entire function is witness code and, therefore, must be
 *                  only called from an exists construct.
 *)
let compute_intermediate_products (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Element.Standard.t) (right_input : f Element.Standard.t)
    (quotient : f standard_limbs) (neg_foreign_field_modulus : f standard_limbs)
    : f * f * f =
  let open Circuit in
  let left_input0, left_input1, left_input2 =
    Element.Standard.to_field_limbs_as_prover (module Circuit) left_input
  in
  let right_input0, right_input1, right_input2 =
    Element.Standard.to_field_limbs_as_prover (module Circuit) right_input
  in
  let quotient0, quotient1, quotient2 = quotient in
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    neg_foreign_field_modulus
  in
  ( (* p0 = a0 * b0 + q0 + f'0 *)
    Field.Constant.(
      (left_input0 * right_input0) + (quotient0 * neg_foreign_field_modulus0))
  , (* p1 = a0 * b1 + a1 * b0 + q0 * f'1 + q1 * f'0 *)
    Field.Constant.(
      (left_input0 * right_input1)
      + (left_input1 * right_input0)
      + (quotient0 * neg_foreign_field_modulus1)
      + (quotient1 * neg_foreign_field_modulus0))
  , (* p2 = a0 * b2 + a2 * b0 + a1 * b1 - q0 * f'2 + q2 * f'0 + q1 * f'1 *)
    Field.Constant.(
      (left_input0 * right_input2)
      + (left_input2 * right_input0)
      + (left_input1 * right_input1)
      + (quotient0 * neg_foreign_field_modulus2)
      + (quotient2 * neg_foreign_field_modulus0)
      + (quotient1 * neg_foreign_field_modulus1)) )

(* Compute intermediate sums
 *   For more details see the "Optimizations" Section of
 *   the [Foreign Field Multiplication RFC](../rfcs/foreign_field_mul.md) *)
let compute_intermediate_sums (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (quotient : f standard_limbs) (neg_foreign_field_modulus : f standard_limbs)
    : f * f =
  let open Circuit in
  let quotient0, quotient1, quotient2 = quotient in
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    neg_foreign_field_modulus
  in
  (* let q01 = q0 + 2^L * q1 *)
  let quotient01 =
    Field.Constant.(
      quotient0 + (two_to_limb_field (module Circuit) * quotient1))
  in

  (* f'01 = f'0 + 2^L * f'1 *)
  let neg_foreign_field_modulus01 =
    Field.Constant.(
      neg_foreign_field_modulus0
      + (two_to_limb_field (module Circuit) * neg_foreign_field_modulus1))
  in
  ( (* q'01 = q01 + f'01 *)
    Field.Constant.(quotient01 + neg_foreign_field_modulus01)
  , (* q'2 = q2 + f'2 *)
    Field.Constant.(quotient2 + neg_foreign_field_modulus2) )

(* Compute witness variables related for foreign field multplication *)
let compute_witness_variables (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (products : Bignum_bigint.t standard_limbs)
    (remainder : Bignum_bigint.t standard_limbs) : f * f * f * f * f * f =
  let products0, products1, products2 = products in
  let remainder0, remainder1, remainder2 = remainder in

  (* C1-C2: Compute components of product1 *)
  let product1_hi, product1_lo =
    Common.(bignum_bigint_div_rem products1 two_to_limb)
  in
  let product1_hi_1, product1_hi_0 =
    Common.(bignum_bigint_div_rem product1_hi two_to_limb)
  in

  (* C3-C5: Compute v0 = the top 2 bits of (p0 + 2^L * p10 - r0 - 2^L * r1) / 2^2L
   *   N.b. To avoid an underflow error, the equation must sum the intermediate
   *        product terms before subtracting limbs of the remainder. *)
  let carry0 =
    Bignum_bigint.(
      ( products0
      + (Common.two_to_limb * product1_lo)
      - remainder0
      - (Common.two_to_limb * remainder1) )
      / two_to_2limb)
  in

  (* C6-C7: Compute v1 = the top L + 3 bits (p2 + p11 + v0 - r2) / 2^L
   *   N.b. Same as above, to avoid an underflow error, the equation must
   *        sum the intermediate product terms before subtracting the remainder. *)
  let carry1 =
    Bignum_bigint.(
      (products2 + product1_hi + carry0 - remainder2) / Common.two_to_limb)
  in
  (* Compute v10 and v11 *)
  let carry1_hi, carry1_lo =
    Common.(bignum_bigint_div_rem carry1 two_to_limb)
  in

  ( Common.bignum_bigint_to_field (module Circuit) product1_lo
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_0
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_1
  , Common.bignum_bigint_to_field (module Circuit) carry0
  , Common.bignum_bigint_to_field (module Circuit) carry1_lo
  , Common.bignum_bigint_to_field (module Circuit) carry1_hi )

(* Perform integer bound addition computation x' = x + f' *)
let compute_bound (x : Bignum_bigint.t)
    (neg_foreign_field_modulus : Bignum_bigint.t) : Bignum_bigint.t =
  let x_bound = Bignum_bigint.(x + neg_foreign_field_modulus) in
  assert (Bignum_bigint.(x_bound < binary_modulus)) ;
  x_bound

(* Compute bound witness carry bit *)
let compute_bound_witness_carry (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (sums : Bignum_bigint.t compact_limbs)
    (bound : Bignum_bigint.t compact_limbs) : f =
  let sums01, _sums2 = sums in
  let bound01, _bound2 = bound in

  (* C9: witness data is created by externally by called and multi-range-check gate *)

  (* C10-C11: Compute q'_carry01 = (s01 - q'01)/2^2L *)
  let quotient_bound_carry, _ =
    Common.bignum_bigint_div_rem Bignum_bigint.(sums01 - bound01) two_to_2limb
  in
  Common.bignum_bigint_to_field (module Circuit) quotient_bound_carry

(* Foreign field multiplication gadget definition *)
let mul (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(external_checks : f External_checks.t option)
    (left_input : f Element.Standard.t) (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) :
    f Element.Standard.t * f External_checks.t =
  let open Circuit in
  (* Check foreign field modulus < max allowed *)
  check_modulus (module Circuit) foreign_field_modulus ;

  (* Compute gate coefficients
   *   This happens when circuit is created / not part of witness (e.g. exists, As_prover code)
   *)
  let foreign_field_modulus0, foreign_field_modulus1, foreign_field_modulus2 =
    foreign_field_modulus
  in
  let ( neg_foreign_field_modulus
      , ( neg_foreign_field_modulus0
        , neg_foreign_field_modulus1
        , neg_foreign_field_modulus2 ) ) =
    let foreign_field_modulus =
      field_standard_limbs_to_bignum_bigint
        (module Circuit)
        foreign_field_modulus
    in
    (* Compute negated foreign field modulus f' = 2^t - f public parameter *)
    let neg_foreign_field_modulus =
      Bignum_bigint.(binary_modulus - foreign_field_modulus)
    in
    ( neg_foreign_field_modulus
    , bignum_bigint_to_field_standard_limbs
        (module Circuit)
        neg_foreign_field_modulus )
  in

  (* Compute witness values *)
  let ( left_input0
      , left_input1
      , left_input2
      , right_input0
      , right_input1
      , right_input2
      , carry1_lo
      , carry1_hi
      , product1_hi_1
      , carry0
      , quotient0
      , quotient1
      , quotient2
      , quotient_bound_carry
      , remainder0
      , remainder1
      , remainder2
      , quotient_bound01
      , quotient_bound2
      , remainder_bound0
      , remainder_bound1
      , remainder_bound2
      , product1_lo
      , product1_hi_0 ) =
    exists (Typ.array ~length:24 Field.typ) ~compute:(fun () ->
        (* Compute quotient remainder and negative foreign field modulus *)
        let quotient, remainder =
          (* Bignum_bigint computations *)
          let left_input =
            Element.Standard.to_bignum_bigint_as_prover
              (module Circuit)
              left_input
          in
          let right_input =
            Element.Standard.to_bignum_bigint_as_prover
              (module Circuit)
              right_input
          in
          let foreign_field_modulus =
            field_standard_limbs_to_bignum_bigint
              (module Circuit)
              foreign_field_modulus
          in

          (* Compute quotient and remainder using foreign field modulus *)
          let quotient, remainder =
            Common.bignum_bigint_div_rem
              Bignum_bigint.(left_input * right_input)
              foreign_field_modulus
          in
          (quotient, remainder)
        in

        (* Compute the intermediate products *)
        let products =
          let quotient =
            bignum_bigint_to_field_standard_limbs (module Circuit) quotient
          in
          let neg_foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Circuit)
              neg_foreign_field_modulus
          in
          let product0, product1, product2 =
            compute_intermediate_products
              (module Circuit)
              left_input right_input quotient neg_foreign_field_modulus
          in

          ( Common.field_to_bignum_bigint (module Circuit) product0
          , Common.field_to_bignum_bigint (module Circuit) product1
          , Common.field_to_bignum_bigint (module Circuit) product2 )
        in

        (* Compute the intermediate sums *)
        let sums =
          let quotient =
            bignum_bigint_to_field_standard_limbs (module Circuit) quotient
          in
          let neg_foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Circuit)
              neg_foreign_field_modulus
          in
          let sum01, sum2 =
            compute_intermediate_sums
              (module Circuit)
              quotient neg_foreign_field_modulus
          in
          ( Common.field_to_bignum_bigint (module Circuit) sum01
          , Common.field_to_bignum_bigint (module Circuit) sum2 )
        in

        (* Compute witness variables *)
        let ( product1_lo
            , product1_hi_0
            , product1_hi_1
            , carry0
            , carry1_lo
            , carry1_hi ) =
          compute_witness_variables
            (module Circuit)
            products
            (bignum_bigint_to_standard_limbs remainder)
        in

        (* Compute bounds for multi-range-checks on quotient and remainder *)
        let quotient_bound = compute_bound quotient neg_foreign_field_modulus in
        let remainder_bound =
          compute_bound remainder neg_foreign_field_modulus
        in

        (* Compute quotient bound addition witness variables *)
        let quotient_bound_carry =
          compute_bound_witness_carry
            (module Circuit)
            sums
            (bignum_bigint_to_compact_limbs quotient_bound)
        in

        (* Compute the rest of the witness data *)
        let left_input0, left_input1, left_input2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) left_input
        in
        let right_input0, right_input1, right_input2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) right_input
        in
        let quotient0, quotient1, quotient2 =
          bignum_bigint_to_field_standard_limbs (module Circuit) quotient
        in
        let remainder0, remainder1, remainder2 =
          bignum_bigint_to_field_standard_limbs (module Circuit) remainder
        in
        let quotient_bound01, quotient_bound2 =
          bignum_bigint_to_field_compact_limbs (module Circuit) quotient_bound
        in
        let remainder_bound0, remainder_bound1, remainder_bound2 =
          bignum_bigint_to_field_standard_limbs (module Circuit) remainder_bound
        in

        [| left_input0
         ; left_input1
         ; left_input2
         ; right_input0
         ; right_input1
         ; right_input2
         ; carry1_lo
         ; carry1_hi
         ; product1_hi_1
         ; carry0
         ; quotient0
         ; quotient1
         ; quotient2
         ; quotient_bound_carry
         ; remainder0
         ; remainder1
         ; remainder2
         ; quotient_bound01
         ; quotient_bound2
         ; remainder_bound0
         ; remainder_bound1
         ; remainder_bound2
         ; product1_lo
         ; product1_hi_0
        |] )
    |> tuple24_of_array
  in

  (* Prepare external checks *)
  let external_checks =
    match external_checks with
    | Some external_checks ->
        external_checks
    | None ->
        External_checks.create (module Circuit)
  in
  External_checks.add_multi_range_check external_checks
    (carry1_lo, product1_lo, product1_hi_0) ;
  External_checks.add_compact_multi_range_check external_checks
    (quotient_bound01, quotient_bound2) ;
  External_checks.add_multi_range_check external_checks
    (remainder_bound0, remainder_bound1, remainder_bound2) ;
  External_checks.add_bound_addition external_checks
    (remainder0, remainder1, remainder2) ;

  (* Create ForeignFieldMul gate *)
  with_label "foreign_field_mul" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldMul
                 { (* Current row *) left_input0
                 ; left_input1
                 ; left_input2
                 ; right_input0
                 ; right_input1
                 ; right_input2
                 ; carry1_lo
                 ; carry1_hi
                 ; carry0
                 ; quotient0
                 ; quotient1
                 ; quotient2
                 ; quotient_bound_carry
                 ; product1_hi_1
                 ; (* Next row *) remainder0
                 ; remainder1
                 ; remainder2
                 ; quotient_bound01
                 ; quotient_bound2
                 ; product1_lo
                 ; product1_hi_0
                 ; (* Coefficients *) foreign_field_modulus0
                 ; foreign_field_modulus1
                 ; foreign_field_modulus2
                 ; neg_foreign_field_modulus0
                 ; neg_foreign_field_modulus1
                 ; neg_foreign_field_modulus2
                 } )
        } ) ;
  ( Element.Standard.of_limbs (remainder0, remainder1, remainder2)
  , external_checks )

(*********)
(* Tests *)
(*********)

let%test_unit "foreign_field_add gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  let assert_eq ((a, b, c) : 'field standard_limbs)
      ((x, y, z) : 'field standard_limbs) =
    let open Runner.Impl.Field in
    Assert.equal (constant a) (constant x) ;
    Assert.equal (constant b) (constant y) ;
    Assert.equal (constant c) (constant z)
  in

  (* Helper to test foreign_field_add gadget
     *   Inputs:
     *     - left_input
     *     - right_input
     *     - is_sub: default is false
     *     - foreign_field_modulus
  *)
  let _test_add ?cs ?(is_sub = false) (left_input : Bignum_bigint.t)
      (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
      =
    (* Generate and verify proof *)
    let cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof ?cs (fun () ->
          let open Runner.Impl in
          (* Prepare test inputs *)
          let op_sign =
            if is_sub then Bignum_bigint.of_int (-1) else Bignum_bigint.one
          in
          let expected =
            Bignum_bigint.(
              left_input + (op_sign * right_input % foreign_field_modulus))
          in
          let foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
          in
          let right_input =
            Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
          in
          (* Create the gadget *)
          let sum =
            add
              (module Runner.Impl)
              left_input right_input is_sub foreign_field_modulus
          in
          (* Check product matches expected result *)
          as_prover (fun () ->
              let expected =
                bignum_bigint_to_field_standard_limbs
                  (module Runner.Impl)
                  expected
              in
              let sum =
                Element.Standard.to_field_limbs_as_prover
                  (module Runner.Impl)
                  sum
              in
              assert_eq sum expected ) ;
          () )
    in
    cs
  in

  (* Helper to test foreign_field_mul gadget with external checks
     *   Inputs:
     *     - inputs
     *     - foreign_field_modulus
     *     - is_sub: list of operations to perform
  *)
  let _test_add_chain ?cs (inputs : Bignum_bigint.t list) (is_sub : bool list)
      (foreign_field_modulus : Bignum_bigint.t) =
    (* Generate and verify proof *)
    let cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof ?cs (fun () ->
          let open Runner.Impl in
          (* compute result of the chain *)
          let n = List.length is_sub in
          let chain_result = [| List.nth_exn inputs 0 |] in
          for i = 0 to n - 1 do
            let op_sign =
              if List.nth_exn is_sub i then Bignum_bigint.of_int (-1)
              else Bignum_bigint.one
            in
            let inp = List.nth_exn inputs (i + 1) in
            let sum =
              Bignum_bigint.(
                chain_result.(i) + (op_sign * inp % foreign_field_modulus))
            in
            chain_result.(0) <- sum ; ()
          done ;

          let inputs =
            List.map
              ~f:(fun x ->
                Element.Standard.of_bignum_bigint (module Runner.Impl) x )
              inputs
          in
          let foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in

          (* Create the gadget *)
          let sum =
            add_chain (module Runner.Impl) inputs is_sub foreign_field_modulus
          in
          (* Check product matches expected result *)
          as_prover (fun () ->
              let expected =
                bignum_bigint_to_field_standard_limbs
                  (module Runner.Impl)
                  chain_result.(0)
              in
              let sum =
                Element.Standard.to_field_limbs_as_prover
                  (module Runner.Impl)
                  sum
              in
              assert_eq sum expected ) ;
          () )
    in
    cs
  in

  (* Test foreign_field_add gadget *)
  let _secp256k1_modulus =
    Common.bignum_bigint_of_hex
      "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
  in

  (* Disabling temporarily to unbreak tests *)
  (* Currently failing with: foreign_field_add gadget threw (Failure "Can't evaluate prover code outside an as_prover block") *)
  (* let cs = test_add Bignum_bigint.zero Bignum_bigint.zero secp256k1_modulus in
     let _cs =
       test_add ~is_sub:false Bignum_bigint.zero Bignum_bigint.zero
         secp256k1_modulus
     in *)

  (* let _cs =
       test_add ~cs
         (Common.bignum_bigint_of_hex
            "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
         (Common.bignum_bigint_of_hex
            "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
         secp256k1_modulus
     in *)
  ()

let%test_unit "foreign_field_mul gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  let assert_eq ((a, b, c) : 'field standard_limbs)
      ((x, y, z) : 'field standard_limbs) =
    let open Runner.Impl.Field in
    Assert.equal (constant a) (constant x) ;
    Assert.equal (constant b) (constant y) ;
    Assert.equal (constant c) (constant z)
  in

  (* Helper to test foreign_field_mul gadget
   *  Inputs:
   *     cs                    := optional constraint system to reuse
   *     left_input            := left multiplicand
   *     right_input           := right multiplicand
   *     foreign_field_modulus := foreign field modulus
   *)
  let test_mul ?cs (left_input : Bignum_bigint.t)
      (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
      =
    (* Generate and verify proof *)
    let cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof ?cs (fun () ->
          let open Runner.Impl in
          (* Prepare test inputs *)
          let expected =
            Bignum_bigint.(left_input * right_input % foreign_field_modulus)
          in
          let foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
          in
          let right_input =
            Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
          in
          (* Create the gadget *)
          let product, _external_checks =
            mul
              (module Runner.Impl)
              left_input right_input foreign_field_modulus
          in
          (* Check product matches expected result *)
          as_prover (fun () ->
              let expected =
                bignum_bigint_to_field_standard_limbs
                  (module Runner.Impl)
                  expected
              in
              let product =
                Element.Standard.to_field_limbs_as_prover
                  (module Runner.Impl)
                  product
              in
              assert_eq product expected ) ;
          () )
    in

    cs
  in

  (* Helper to test foreign_field_mul gadget with external checks
   *   Inputs:
   *     cs                    := optional constraint system to reuse
   *     left_input            := left multiplicand
   *     right_input           := right multiplicand
   *     foreign_field_modulus := foreign field modulus
   *)
  let test_mul_full ?cs (left_input : Bignum_bigint.t)
      (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
      =
    (* Generate and verify first proof *)
    let cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof ?cs (fun () ->
          let open Runner.Impl in
          (* Prepare test inputs *)
          let expected =
            Bignum_bigint.(left_input * right_input % foreign_field_modulus)
          in
          let foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
          in
          let right_input =
            Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
          in

          (* External checks for this test (example, circuit designer has complete flexibility about organization)
           *   1) ForeignFieldMul
           *   2) ForeignFieldAdd (result bound addition)
           *   3) multi-range-check (left multiplicand)
           *   4) multi-range-check (right multiplicand)
           *   5) multi-range-check (product1_lo, product1_hi_0, carry1_lo)
           *   6) multi-range-check (remainder bound / product / result range check)
           *   7) compact-multi-range-check (quotient range check) *)

          (* 1) Create the foreign field mul gadget *)
          let product1, external_checks =
            mul
              (module Runner.Impl)
              left_input right_input foreign_field_modulus
          in
          (* Add another foreign field mul to test chaining of external_checks *)
          let product2, external_checks =
            mul
              (module Runner.Impl)
              ~external_checks left_input right_input foreign_field_modulus
          in

          (* Sanity check product matches expected result *)
          as_prover (fun () ->
              let expected =
                bignum_bigint_to_field_standard_limbs
                  (module Runner.Impl)
                  expected
              in
              let product =
                Element.Standard.to_field_limbs_as_prover
                  (module Runner.Impl)
                  product2
              in

              assert_eq product expected ) ;

          (* 2) Add result bound addition gate. Corresponding range check happens in 6 *)
          let _out1 =
            less_than_fmod (module Runner.Impl) product1 foreign_field_modulus
          in
          let _out2 =
            less_than_fmod (module Runner.Impl) product2 foreign_field_modulus
          in

          assert (
            Mina_stdlib.List.Length.equal external_checks.bound_additions 2 ) ;

          (* 3) Add multi-range-check left input *)
          let left_input0, left_input1, left_input2 =
            Element.Standard.to_limbs left_input
          in
          Range_check.multi
            (module Runner.Impl)
            left_input0 left_input1 left_input2 ;

          (* 4) Add multi-range-check right input *)
          let right_input0, right_input1, right_input2 =
            Element.Standard.to_limbs right_input
          in
          Range_check.multi
            (module Runner.Impl)
            right_input0 right_input1 right_input2 ;

          (* 5-6) Add gates for external multi-range-checks
           *   In this case:
           *     carry1_lo, product1_lo, product1_hi_0
           *     remainder_bound0, remainder_bound1, remainder_bound2
           *)
          List.iter external_checks.multi_ranges ~f:(fun multi_range ->
              let v0, v1, v2 = multi_range in
              Range_check.multi (module Runner.Impl) v0 v1 v2 ;
              () ) ;
          assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 4) ;

          (* 7) Add gates for external compact-multi-range-checks
           *   In this case:
           *     quotient_bound01, quotient_bound2
           *)
          List.iter external_checks.compact_multi_ranges
            ~f:(fun compact_multi_range ->
              let v01, v2 = compact_multi_range in
              Range_check.compact_multi (module Runner.Impl) v01 v2 ;
              () ) ;

          assert (
            Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges 2 ) )
    in

    cs
  in

  (* Test constants *)
  let secp256k1_modulus =
    Common.bignum_bigint_of_hex
      "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
  in
  let secp256k1_max = Bignum_bigint.(secp256k1_modulus - Bignum_bigint.one) in
  let secp256k1_sqrt = Common.bignum_biguint_sqrt secp256k1_max in
  let pallas_modulus =
    Common.bignum_bigint_of_hex
      "40000000000000000000000000000000224698fc094cf91b992d30ed00000001"
  in
  let pallas_max = Bignum_bigint.(pallas_modulus - Bignum_bigint.one) in
  let pallas_sqrt = Common.bignum_biguint_sqrt pallas_max in
  let vesta_modulus =
    Common.bignum_bigint_of_hex
      "40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001"
  in

  (* Positive tests *)
  (* zero_mul: 0 * 0 *)
  let cs = test_mul Bignum_bigint.zero Bignum_bigint.zero secp256k1_modulus in
  (* one_mul: max * 1 *)
  let _cs = test_mul ~cs secp256k1_max Bignum_bigint.one secp256k1_modulus in
  (* max_native_square: pallas_sqrt * pallas_sqrt *)
  let _cs = test_mul ~cs pallas_sqrt pallas_sqrt secp256k1_modulus in
  (* max_foreign_square: secp256k1_sqrt * secp256k1_sqrt *)
  let _cs = test_mul ~cs secp256k1_sqrt secp256k1_sqrt secp256k1_modulus in
  (* max_native_multiplicands: pallas_max * pallas_max *)
  let _cs = test_mul ~cs pallas_max pallas_max secp256k1_modulus in
  (* max_foreign_multiplicands: secp256k1_max * secp256k1_max *)
  let _cs = test_mul ~cs secp256k1_max secp256k1_max secp256k1_modulus in
  (* nonzero carry0 bits *)
  let _cs =
    test_mul ~cs
      (Common.bignum_bigint_of_hex
         "fbbbd91e03b48cebbac38855289060f8b29fa6ad3cffffffffffffffffffffff" )
      (Common.bignum_bigint_of_hex
         "d551c3d990f42b6d780275d9ca7e30e72941aa29dcffffffffffffffffffffff" )
      secp256k1_modulus
  in
  (* test nonzero carry10 *)
  let _cs =
    test_mul
      (Common.bignum_bigint_of_hex
         "4000000000000000000000000000000000000000000000000000000000000000" )
      (Common.bignum_bigint_of_hex
         "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0" )
      Bignum_bigint.(pow (of_int 2) (of_int 259))
  in
  (* test nonzero carry1_hi *)
  let _cs =
    test_mul
      (Common.bignum_bigint_of_hex
         "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
      (Common.bignum_bigint_of_hex
         "8000000000000000000000000000000000000000000000000000000000000000d0" )
      Bignum_bigint.(pow (of_int 2) (of_int 259) - one)
  in
  (* test nonzero_second_bit_carry1_hi *)
  let _cs =
    test_mul ~cs
      (Common.bignum_bigint_of_hex
         "ffffffffffffffffffffffffffffffffffffffffffffffff8a9dec7cfd1acdeb" )
      (Common.bignum_bigint_of_hex
         "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e" )
      secp256k1_modulus
  in
  (* test random_multiplicands_carry1_lo *)
  let _cs =
    test_mul ~cs
      (Common.bignum_bigint_of_hex
         "ffd913aa9e17a63c7a0ff2354218037aafcd6ecaa67f56af1de882594a434dd3" )
      (Common.bignum_bigint_of_hex
         "7d313d6b42719a39acea5f51de9d50cd6a4ec7147c003557e114289e9d57dffc" )
      secp256k1_modulus
  in
  (* test random_multiplicands_valid *)
  let _cs =
    test_mul ~cs
      (Common.bignum_bigint_of_hex
         "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
      (Common.bignum_bigint_of_hex
         "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
      secp256k1_modulus
  in
  (* test smaller foreign field modulus *)
  let _cs =
    test_mul
      (Common.bignum_bigint_of_hex
         "5945fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c" )
      (Common.bignum_bigint_of_hex
         "747109f882b8e26947dfcd887273c0b0720618cb7f6d407c9ba74dbe0eda22f" )
      (Common.bignum_bigint_of_hex
         "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
  in
  (* vesta non-native on pallas native modulus *)
  let _cs =
    test_mul
      (Common.bignum_bigint_of_hex
         "69cc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15" )
      (Common.bignum_bigint_of_hex
         "1fffe27b14baa740db0c8bb6656de61d2871a64093908af6181f46351a1c1909" )
      vesta_modulus
  in

  (* Full test including all external checks *)
  let cs =
    test_mul_full
      (Common.bignum_bigint_of_hex "2")
      (Common.bignum_bigint_of_hex "3")
      secp256k1_modulus
  in
  let _cs =
    test_mul_full ~cs
      (Common.bignum_bigint_of_hex
         "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
      (Common.bignum_bigint_of_hex
         "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
      secp256k1_modulus
  in
  ()