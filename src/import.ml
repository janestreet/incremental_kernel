[%%import "debug.mlh"]

open Core_kernel

include Int.Replace_polymorphic_compare

(* All [assert]s and other checks throughout the code are guarded by [if debug].  The
   DEBUG variable is set in the lib [incremental_lib] and unset in the lib
   [incremental_debug], but apart from that they are identical.  Tests are run with both
   the production and debug lib, and users can choose to build with the debug library, if
   they suspect they found a bug in incremental. *)

[%%if JSC_DEBUG]
let debug = true
[%%else]
let debug = false
[%%endif]

(* All debug messages throughout the code are guarded by [if verbose]. *)
let verbose = false

let concat = String.concat

let tag name a sexp_of_a = (name, a) |> [%sexp_of: string * a]

let sexp_of_time_ns =
  ref (fun t ->
    sexp_of_string
      (sprintf "Time_ns.of_int_ns_since_epoch %d" (Time_ns.to_int_ns_since_epoch t)))
;;

let sexp_of_time_ns_span =
  ref (fun t ->
    sexp_of_string
      (sprintf "Time_ns.Span.of_int_ns %d" (Time_ns.Span.to_int_ns t)))
;;

module Time_ns = struct
  include (Time_ns : module type of struct include Time_ns end
           with module Span := Time_ns.Span)
  let sexp_of_t t = !sexp_of_time_ns t

  module Span = struct
    include Time_ns.Span
    let sexp_of_t t = !sexp_of_time_ns_span t
  end
end

let () = Debug.should_print_backtrace := false

module Array = struct
  include Array

  (* Not defining aliases in production mode, since they break type specialization of
     array accesses. *)
  [%%if JSC_DEBUG]
  let unsafe_get = get
  let unsafe_set = set
  [%%endif]

  (* Requires [len >= length t]. *)
  let realloc t ~len a =
    let new_t = create ~len a in
    Array.blit
      ~src:t     ~src_pos:0
      ~dst:new_t ~dst_pos:0
      ~len:(length t);
    new_t
  ;;
end
