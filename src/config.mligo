(*
    refund_threshold and super_majority
    are represented with scale = 2, ex. 80 = .80 = 80%

    x_delay and x_period are represented by time units in seconds
*)
type t =
    [@layout:comb]
    {
        deposit_amount: nat;
        (* ^ The amount of tokens required to be deposited when creating a proposal *)

        base_token_score: nat;
        (* ^ The base token score added to each user token score for voting *)

        base_reput_score: nat;
        (* ^ The base reputation score added to each user reputation score for voting *)

        base_fidel_score: nat;
        (* ^ The base fidelity score added to each user fidel score for voting *)

        refund_threshold: nat;
        (* ^ The minimal participation percentage of "yes" votes weighting power required for the deposit to be refunded *)

        super_majority: nat;
        (* ^ The minimal participation percentage of "yes" votes weighting power required for a proposal to pass *)

        start_delay: nat;
        (* ^ The delay for the vote to start *)

        voting_period: nat;
        (* ^ The period during which voting is live *)

        timelock_delay: nat;
        (* ^ Delay before an approved proposal can be executed *)

        timelock_period: nat;
        (* ^ The period during which a timelock can be executed *)

        burn_address: address;
        (* ^ The burn address for unrefunded deposits *)
    }
