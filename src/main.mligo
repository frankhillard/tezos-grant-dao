#import "./constants.mligo" "Constants"
#import "./errors.mligo" "Errors"
#import "./storage.mligo" "Storage"
#import "./token.mligo" "Token"
#import "./vault.mligo" "Vault"
#import "./timelock.mligo" "Timelock"
#import "./proposal.mligo" "Proposal"
#import "./vote.mligo" "Vote"
#import "./outcome.mligo" "Outcome"
#import "./lambda.mligo" "Lambda"
#import "./whitelist.mligo" "Whitelist"

type parameter =
    SubmitAccessRequest of Whitelist.tezprofile
    | AcceptAccessRequest of address
    | Propose of Proposal.make_params
    | Lock of Vault.amount_
    | Release of Vault.amount_
    | Vote of Vote.choice
    | End_vote
    | Cancel of nat option
    | Execute of Outcome.execute_params

type storage = Storage.t
type result = operation list * storage

(**
    [_check_is_member(seek_address, s)] checks if the user is a member in the map of members
    Raises [Errors.not_a_member] if the user is not in the map of members
*)
let _check_is_member(seek_address, s : address * storage) =
    match Map.find_opt seek_address s.members with
        | None -> failwith Errors.not_a_member
        | Some (_) -> ()

(**
    [submit_request(b, s)] creates a request for access in the map of requests
    Raises [Errors.request_already_exists] if the sender already has a request
*)
let submit_access_request(tezprofile, s : Whitelist.tezprofile * storage) : result =
    match Map.find_opt (Tezos.get_sender()) s.members with
        | Some (_) -> failwith Errors.already_a_member
        | None -> (match Map.find_opt (Tezos.get_sender()) s.requests with
                    | Some (_) -> failwith Errors.request_already_exists
                    | None ->
                        let new_requests = Map.add (Tezos.get_sender()) tezprofile s.requests in
                        ([], { s with requests = new_requests}))

(**
    [accept_request(c, s)] accepts a request for an access in the map of requests,
    and creates a membership in the map of members
    Raises [Errors.request_does_not_exist] if the applicant does not have a request
*)
let accept_access_request(applicant, s : address * storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
    match Map.find_opt applicant s.requests with
        | None -> failwith Errors.request_does_not_exist
        | Some applicant_tezprofile ->
            let new_requests = Map.remove applicant s.requests in
            let new_members = Map.add applicant applicant_tezprofile s.members in
            ([], {s with requests = new_requests; members = new_members})

(**
    [propose(p, s)] creates a proposal from create parameters [p], then transfers configured
    deposit_amount of tokens to the DAO contract and updates storage [s] with the new proposal.
    Raises [Errors.proposal_already_exists] if there is already a proposal as only one
    proposal can exists at a time.
    Raises [Errors.receiver_not_found] if the governance token contract entrypoint is not found.
*)
let propose (p, s : Proposal.make_params * storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
    match s.proposal with
        Some(_) -> failwith Errors.proposal_already_exists
        | None -> [Token.transfer(
            s.governance_token,
            Tezos.get_sender(),
            Tezos.get_self_address(),
            s.config.deposit_amount
        )], Storage.create_proposal(
            Proposal.make(p, s.config.start_delay, s.config.voting_period),
            s)

(**
    [lock(amount_)] creates an operation for token transfer between the owner and the DAO contract with [amount_],
    and updates storage [s] with the vault new balance to keep tracks of the transfer.
    Raises [Errors.voting_period] if a proposal exists and a vote is ongoing.
    Raises [FA2.Errors.ins_balance] if the owner has insufiscient balance.
    Requires the DAO address to have been added as operator on the governance token.
*)
let lock (amount_, s : nat * storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
    let () = Proposal._check_no_vote_ongoing(s.proposal) in
    let current_amount = Vault.get_for_user(s.vault, Tezos.get_sender()) in

    let updated_score = match Big_map.find_opt (Tezos.get_sender()) s.user_score with
          None -> {reputation = 0n; fidelity=0n; last_date = Tezos.get_now ();}
        | Some(p) ->
            if current_amount = 0n then
            {reputation = p.reputation; fidelity = p.fidelity; last_date = Tezos.get_now();}
            else
            {reputation = p.reputation;
            fidelity = p.fidelity + abs(Tezos.get_now() - p.last_date);
            last_date = Tezos.get_now();}
    in
    let updated_score_map = Big_map.update (Tezos.get_sender()) (Some updated_score) s.user_score in

    [Token.transfer(s.governance_token, Tezos.get_sender(), Tezos.get_self_address(), amount_)],
    Storage.update_vault(Vault.update_for_user(
        s.vault,
        Tezos.get_sender(),
        current_amount + amount_), {s with user_score = updated_score_map})

(**
    [release(amount_, s)] creates an operation for token transfer between the DAO and the owner with [amount_],
    and updates storage [s] with the vault new balance to keep tracks of the transfer.
    Raises [Errors.voting_period] if a vote is ongoing.
    Raises [Errors.no_locked_tokens] if the sender has no locked tokens.
    Raises [Errors.not_enough_balance] if [amount_] is superior to actual balance.
    Raises [FA2.Errors.ins_balance] if the DAO has insufiscient balance.
*)
let release (amount_, s : nat * storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
    let () = Proposal._check_no_vote_ongoing(s.proposal) in
    let current_amount = Vault.get_for_user_exn(s.vault, Tezos.get_sender()) in
    let _check_balance = assert_with_error
        (current_amount >= amount_)
        Errors.not_enough_balance in

    let updated_score = match Big_map.find_opt (Tezos.get_sender()) s.user_score with
          None -> failwith Errors.score_do_not_exist
        | Some(p) ->
            if current_amount = 0n then
            {reputation = p.reputation; fidelity = p.fidelity; last_date = Tezos.get_now();}
            else
            {reputation = p.reputation;
            fidelity = p.fidelity + abs(Tezos.get_now() - p.last_date);
            last_date = Tezos.get_now();}
    in
    let updated_score_map = Big_map.update (Tezos.get_sender()) (Some updated_score) s.user_score in

    [Token.transfer(s.governance_token, Tezos.get_self_address(), Tezos.get_sender(), amount_)],
    Storage.update_vault(Vault.update_for_user(
        s.vault,
        Tezos.get_sender(),
        abs(current_amount - amount_)), {s with user_score = updated_score_map})

(**
    [vote(choice, s)] updates current proposal with the sender [choice] along with its voting power, and
    returns the updated storage [s]
    Raises [Errors.no_proposal] if there is no current proposal.
    Raises [Errors.not_voting_period] if the vote is not open.
    Raises [Errors.no_locked_tokens] if the sender has no locked tokens.
*)
let vote (choice, s : bool * storage) : storage =
    let () = _check_is_member((Tezos.get_sender()), s) in
    match s.proposal with
        None -> failwith Errors.no_proposal
        | Some(p) -> let () = Proposal._check_is_voting_period(p) in
            let amount_ = Vault.get_for_user_exn(s.vault, Tezos.get_sender()) in
            Storage.update_votes(p, (choice, amount_), s)



let update_score_end_vote (addr, usr_score : address * Storage.score) : Storage.score =

    let score = match Big_map.find_opt addr usr_score with
        None -> {reputation = 0n; fidelity=0n; last_date = Tezos.get_now ();}
        | Some(p) -> {
            reputation = 1n + p.reputation;
            fidelity = abs(Tezos.get_now() - p.last_date) + p.fidelity;
            last_date = Tezos.get_now ();}
    in
    Big_map.update addr (Some score) usr_score


(**
    [end_vote(s)] creates an operation of transfer from the DAO to either the proposal creator, or the
    configured burn_address, and updates storage [s] with new outcome.
    Raises [Errors.no_proposal] if there is no current proposal
    Raises [Errors.fa2_total_supply_not_found] if the configured governance_token total supply
    could not be found.
*)
let end_vote (s : storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
    match s.proposal with
        None -> failwith Errors.no_proposal
        | Some(p) -> let () = Proposal._check_voting_period_ended(p) in

            let folded =
                fun (usr_score_acc, (addr, (_, _)) : Storage.score * (address * Vote.t)) ->
                    let score = match Big_map.find_opt addr usr_score_acc with
                        None -> {reputation = 0n; fidelity=0n; last_date = Tezos.get_now ();}
                        | Some(p) -> {
                        reputation = 1n + p.reputation;
                        fidelity = abs(Tezos.get_now() - p.last_date) + p.fidelity;
                        last_date = Tezos.get_now ();} in
                    Big_map.update addr (Some score) usr_score_acc in
            let updated_score_map = Map.fold folded p.votes s.user_score in

            let outcome = Outcome.make(
                    p,
                    s.config.refund_threshold,
                    s.config.super_majority,
                    s.config.base_token_score,
                    s.config.base_reput_score,
                    s.config.base_fidel_score,
                    s.user_score
                ) in
            let (_, state) = outcome in
            let transfer_to_addr = match state with
                Rejected_(WithoutRefund) -> s.config.burn_address
                | _ -> Tezos.get_sender()
            in
            ([Token.transfer(
                s.governance_token,
                Tezos.get_self_address(),
                transfer_to_addr,
                s.config.deposit_amount)]
            ), Storage.add_outcome(outcome, {s with user_score = updated_score_map})

(**
    [cancel (outcome_key_opt, s)] creates an operation of transfer of the deposited amount to the
    configured burn_address, and updates storage [s] with either an outcome creation of current
    proposal with its state canceled, or an update of the matched outcome at [outcome_key_opt]
    with its state Canceled.
    Raises [Errors.nothing_to_cancel] if [outcome_key_opt] is None and there is no current proposal.
    Raises [Errors.voting_period] if there is a current proposal and the current block minimal
    injection time belongs to the proposal voting period.
    Raises [Errors.not_creator] is the sender is not the proposal creator.
    Raises [Errors.outcome_not_found] if [outcome_key_opt] is not None, but it does not exists.
    Raises [Errors.already_executed] if the proposal have already been executed.
    Raises [Errors.timelock_not_found] if the outcome timelock does not exists.
    Raises [Errors.timelock_unlocked] if the outcome timelock is unlocked, a proposal outcome cannot be
    canceled if it is unlocked.
*)
let cancel (outcome_key_opt, s : nat option * storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
   [Token.transfer(
        s.governance_token,
        Tezos.get_self_address(),
        s.config.burn_address,
        s.config.deposit_amount)
   ], (match outcome_key_opt with
        None -> (match s.proposal with
            None -> failwith Errors.nothing_to_cancel
            | Some(p) -> let () = Proposal._check_not_voting_period(p) in
                let _check_sender_is_creator = assert_with_error
                    (p.creator = Tezos.get_sender())
                    Errors.not_creator in
                Storage.add_outcome((p, Canceled), s))
        | Some(outcome_key) -> (match Big_map.find_opt outcome_key s.outcomes with
            None -> failwith Errors.outcome_not_found
            | Some(o) -> let (p, state) = o in
            let _check_sender_is_creator = assert_with_error
                (p.creator = Tezos.get_sender())
                Errors.not_creator in
            let _check_not_executed = assert_with_error
                (state <> Executed)
                Errors.already_executed in
            let () = Timelock._check_locked(p.timelock) in
            Storage.update_outcome(outcome_key, (p, Canceled), s)))

(**
    [execute(outcome_key, packed, s)] executes [packed] lambda and returns an operation list
    and the updated storage [s]. A lambda can either create an operation list or update the config.
    Raises: [Errors.outcome_not_found] if [outcome_key] does not occur in [Storage.outcomes].
    Raises: [Errors.canceled|Errors.already_executed|Errors.not_executable] if
    the outcome state is not equal to [Accepted].
    Raises: [Errors.timelock_not_found|Errors.timelock_locked] if a timelock
    does not exists or is locked.
    Raises [Errors.lambda_not_found|Errors.lambda_wrong_packed_data] if the lambda does not exists,
    or is not matching the stored hash.
    Raises [Errors.wrong_lambda_kind] if the unpacking of the lambda fails.
*)
let execute (outcome_key, packed, s: nat * bytes * storage) : result =
    let () = _check_is_member((Tezos.get_sender()), s) in
    let proposal = (match Big_map.find_opt outcome_key s.outcomes with
        None -> failwith Errors.outcome_not_found
        | Some(o) -> Outcome.get_proposal(o)) in

    let () = Timelock._check_unlocked(proposal.timelock) in
    let lambda_ = Lambda.validate(proposal.lambda, packed) in

    match lambda_.1 with
        OperationList -> (match (Bytes.unpack packed : Lambda.operation_list option) with
            Some(f) -> f(), Storage.update_outcome(outcome_key, (proposal, Executed), s)
            | None -> failwith Errors.wrong_lambda_kind)
        | ParameterChange -> (match (Bytes.unpack packed : Lambda.parameter_change option) with
            Some(f) ->
                Constants.no_operation,
                Storage.update_outcome(
                    outcome_key,
                    (proposal, Executed),
                    Storage.update_config(f,s)
                )
            | None -> failwith Errors.wrong_lambda_kind)

(**
    Raises [Errors.not_zero_amount] if tez amount is sent.
*)
let main (action, store : parameter * storage) : result =
    let _check_amount_is_zero = assert_with_error (Tezos.get_amount() = 0tez) Errors.not_zero_amount in
    match action with
        SubmitAccessRequest b -> submit_access_request(b, store)
        | AcceptAccessRequest c -> accept_access_request(c, store)
        | Propose p -> propose(p, store)
        | Cancel n_opt -> cancel(n_opt, store)
        | Lock n -> lock(n, store)
        | Release n -> release(n, store)
        | Execute p -> execute(p.outcome_key, p.packed, store)
        | Vote v -> Constants.no_operation, vote(v, store)
        | End_vote -> end_vote(store)
