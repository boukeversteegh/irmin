(* Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. *)

module type S = sig
  type t

  type key

  type value = int64 * int * char

  val v :
    ?fresh:bool ->
    ?readonly:bool ->
    log_size:int ->
    string ->
    t

  val clear : t -> unit

  val flush : t -> unit

  val add : t -> key -> value -> unit

  val mem : t -> key -> bool

  val find : t -> key -> value option
end

module Make (K : Irmin.Hash.S) = struct
  module Key = struct
    type t = K.t

    let pp ppf t = Irmin.Type.pp K.t ppf t

    let hash t = Irmin.Type.short_hash K.t t

    let hash_size = 60

    let equal x y = Irmin.Type.equal K.t x y

    let encode x = Irmin.Type.to_bin_string K.t x

    let encoded_size = K.hash_size

    let decode s off =
      let _, v = Irmin.Type.decode_bin ~headers:false K.t s off in
      v
  end

  module Val = struct
    type t = int64 * int * char

    let pp = Irmin.Type.(pp (triple int64 int char))

    let encode (off, len, kind) =
      Irmin.Type.(to_bin_string (triple int64 int32 char))
        (off, Int32.of_int len, kind)

    let decode s off =
      let off, len, kind =
        snd (Irmin.Type.(decode_bin (triple int64 int32 char)) s off)
      in
      (off, Int32.to_int len, kind)

    let encoded_size = (64 / 8) + (32 / 8) + 1
  end

  module Index = Index_unix.Make (Key) (Val)

  type t = Index.t

  type key = K.t

  type value = Val.t

  let v = Index.v

  let clear = Index.clear

  let flush = Index.flush

  let add t k v = if not (Index.mem t k) then Index.add t k v

  let mem = Index.mem

  let find t k =
    match Index.find_all t k with
    | [] -> None
    | [ h ] -> Some h
    | _ -> assert false
end
