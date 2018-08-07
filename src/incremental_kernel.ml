(* This module is mostly a wrapper around [State] functions. *)

open! Core_kernel
open! Import

include Incremental_kernel_intf

module type Incremental_config = Config.Incremental_config

module Config = Config

module Make_with_config (Incremental_config : Incremental_config) () = struct

  module Before_or_after = Before_or_after

  module Cutoff = Cutoff

  module State = struct

    include State

    let t = create (module Incremental_config) ~max_height_allowed:128
  end

  let state = State.t

  module Scope = struct

    include Scope

    let current () = state.current_scope

    let within t ~f = State.within_scope state t ~f

  end

  include Node

  module Node_update = On_update_handler.Node_update

  type 'a incremental = 'a t

  let const a = State.const state a
  let return = const

  let observe ?should_finalize t = State.create_observer state t ?should_finalize

  let map  t1 ~f                         = State.map  state t1                         ~f
  let map2 t1 t2 ~f                      = State.map2 state t1 t2                      ~f
  let map3 t1 t2 t3 ~f                   = State.map3 state t1 t2 t3                   ~f
  let map4 t1 t2 t3 t4 ~f                = State.map4 state t1 t2 t3 t4                ~f
  let map5 t1 t2 t3 t4 t5 ~f             = State.map5 state t1 t2 t3 t4 t5             ~f
  let map6 t1 t2 t3 t4 t5 t6 ~f          = State.map6 state t1 t2 t3 t4 t5 t6          ~f
  let map7 t1 t2 t3 t4 t5 t6 t7 ~f       = State.map7 state t1 t2 t3 t4 t5 t6 t7       ~f
  let map8 t1 t2 t3 t4 t5 t6 t7 t8 ~f    = State.map8 state t1 t2 t3 t4 t5 t6 t7 t8    ~f
  let map9 t1 t2 t3 t4 t5 t6 t7 t8 t9 ~f = State.map9 state t1 t2 t3 t4 t5 t6 t7 t8 t9 ~f

  let bind t            ~f = State.bind  state t           ~f
  let bind2 t1 t2       ~f = State.bind2 state t1 t2       ~f
  let bind3 t1 t2 t3    ~f = State.bind3 state t1 t2 t3    ~f
  let bind4 t1 t2 t3 t4 ~f = State.bind4 state t1 t2 t3 t4 ~f

  module Infix = struct
    let ( >>| ) t f = map t ~f
    let ( >>= ) t f = bind t ~f
  end

  include Infix

  let join t = State.join state t

  let if_ test ~then_ ~else_ = State.if_ state test ~then_ ~else_

  let lazy_from_fun f = State.lazy_from_fun state ~f

  let default_hash_table_initial_size = State.default_hash_table_initial_size

  let memoize_fun_by_key ?initial_size hashable project_key f =
    State.memoize_fun_by_key ?initial_size state hashable project_key f
  ;;

  let memoize_fun ?initial_size hashable f =
    memoize_fun_by_key ?initial_size hashable Fn.id f
  ;;

  let array_fold ts ~init ~f = State.array_fold state ts ~init ~f

  let reduce_balanced ts ~f ~reduce =
    Reduce_balanced.create state ts ~f ~reduce
  ;;

  let unordered_array_fold ?full_compute_every_n_changes ts ~init ~f ~f_inverse =
    State.unordered_array_fold state ts ~init ~f ~f_inverse
      ?full_compute_every_n_changes
  ;;

  let opt_unordered_array_fold ?full_compute_every_n_changes ts ~init ~f ~f_inverse =
    State.opt_unordered_array_fold state ts ~init ~f ~f_inverse
      ?full_compute_every_n_changes
  ;;

  let all     ts = State.all     state ts
  let exists  ts = State.exists  state ts
  let for_all ts = State.for_all state ts

  let sum ?full_compute_every_n_changes ts ~zero ~add ~sub =
    State.sum state ?full_compute_every_n_changes ts ~zero ~add ~sub
  ;;

  let opt_sum ?full_compute_every_n_changes ts ~zero ~add ~sub =
    State.opt_sum state ?full_compute_every_n_changes ts ~zero ~add ~sub
  ;;

  let sum_int   ts = State.sum_int   state ts
  let sum_float ts = State.sum_float state ts

  module Var = struct

    include Var

    let create ?use_current_scope value = State.create_var ?use_current_scope state value

    let set t value = State.set_var state t value

    let value t = t.value

    let watch t = t.watch

    (* We override [sexp_of_t] to just show the value, rather than the internal
       representation. *)
    let sexp_of_t sexp_of_a t = t.value |> [%sexp_of: a]

  end

  module Observer = struct

    include Observer

    module Update = struct
      type 'a t =
        | Initialized of 'a
        | Changed of 'a * 'a
        | Invalidated
      [@@deriving compare, sexp_of]
    end

    let on_update_exn t ~(f : _ Update.t -> unit) =
      State.observer_on_update_exn state t
        ~f:(function
          | Necessary a      -> f (Initialized a)
          | Changed (a1, a2) -> f (Changed (a1, a2))
          | Invalidated      -> f Invalidated
          | Unnecessary ->
            failwiths "Incremental bug -- Observer.on_update_exn got unexpected update Unnecessary"
              t [%sexp_of: _ t])
    ;;

    let disallow_future_use t = State.disallow_future_use state !t
    let value               t = State.observer_value      state t
    let value_exn           t = State.observer_value_exn  state t

    (* We override [sexp_of_t] to just show the value, rather than the internal
       representation. *)
    let sexp_of_t sexp_of_a t = value t |> [%sexp_of: a Or_error.t]

  end

  let alarm_precision = Timing_wheel_ns.alarm_precision state.timing_wheel

  let now () = State.now state

  let watch_now () = state.now.watch

  let at time                        = State.at            state time
  let after span                     = State.after         state span
  let at_intervals span              = State.at_intervals  state span
  let advance_clock ~to_             = State.advance_clock state ~to_
  let step_function ~init steps      = State.step_function state ~init steps
  let snapshot t ~at ~before         = State.snapshot      state t ~at ~before

  let freeze ?(when_ = fun _ -> true) t = State.freeze state t ~only_freeze_when:when_

  let depend_on t ~depend_on = State.depend_on state t ~depend_on

  let necessary_if_alive input = State.necessary_if_alive state input

  module Update = On_update_handler.Node_update

  let on_update t ~f = State.node_on_update state t ~f

  let stabilize () = State.stabilize state

  let am_stabilizing () = State.am_stabilizing state

  let save_dot file = State.save_dot state file

  (* We override [sexp_of_t] to show just the value, rather than the internal
     representation.  We only show the value if it is necessary and valid. *)
  let sexp_of_t sexp_of_a t =
    if not (is_valid t)
    then "<invalid>" |> [%sexp_of: string]
    else if not (is_necessary t)
    then "<unnecessary>" |> [%sexp_of: string]
    else if Uopt.is_none t.value_opt
    then "<uncomputed>" |> [%sexp_of: string]
    else unsafe_value t |> [%sexp_of: a]
  ;;

  module Expert = struct
    module Dependency = struct
      include Expert1.Dependency
      let value t = value State.t t
    end
    module Node = struct
      include Expert1.Node

      let create ?on_observability_change f =
        Expert1.Node.create State.t ?on_observability_change f
      ;;

      let make_stale t = Expert1.Node.make_stale state t

      let invalidate t = Expert1.Node.invalidate State.t t

      let add_dependency t edge = Expert1.Node.add_dependency State.t t edge

      let remove_dependency t edge  = Expert1.Node.remove_dependency State.t t edge
    end
  end

  module Let_syntax = struct
    let return = return
    let ( >>| ) = ( >>| )
    let ( >>= ) = ( >>= )

    module Let_syntax = struct
      let bind = bind
      let map  = map

      let both t1 t2 = map2 t1 t2 ~f:(fun x1 x2 -> (x1, x2))

      module Open_on_rhs = struct
        let watch = Var.watch
      end
    end
  end
end

module Make () = Make_with_config (Config.Default ()) ()

module Incremental = struct
  module Make = Make
end

module Incremental_intf = struct
  module type S = S
end

module Private = struct
  module Balanced_reducer = Balanced_reducer
  include Import
end
