open Core_kernel

(*_ See the Jane Street Style Guide for an explanation of [Private] submodules:

  https://opensource.janestreet.com/standards/#private-submodules *)
module Private : sig
  module Import : sig
    val debug : bool
    val verbose : bool
    val sexp_of_time_ns : (Time_ns.t -> Sexp.t) ref
    val sexp_of_time_ns_span : (Time_ns.Span.t -> Sexp.t) ref
  end
end

module Config : module type of Incremental_kernel.Config

module Incremental_intf : sig
  module type S_abstract_times = Incremental_kernel.Incremental_intf.S_abstract_times
end

module Incremental : module type of Incremental_kernel.Incremental
