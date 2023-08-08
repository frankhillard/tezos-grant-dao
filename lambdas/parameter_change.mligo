#import "../src/lambda.mligo" "Lambda"

(*
    A parameter change lambda is just a new record of type Config.t,
    the storage will be updated with the differences when the lambda is
    executed
*)

let lambda_ : Lambda.parameter_change =
  fun () ->
    {
        deposit_amount = 4n;
        base_token_score = 1_000_000n;
        base_reput_score = 10n;
        base_fidel_score = 31_536_000n;
        refund_threshold = 32n;
        super_majority = 80n;
        start_delay = 360n;
        voting_period = 1440n;
        timelock_delay = 360n;
        timelock_period = 720n;
        burn_address = ("tz1burnburnburnburnburnburnburjAYjjX": address);
    }
