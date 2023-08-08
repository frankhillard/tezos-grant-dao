#import "./errors.mligo" "Errors"

type choice = bool
type t = (choice * nat)
type votes = (address, t) map

type scores = {
    reputation: nat;
    fidelity: nat;
    last_date: timestamp;
}

(**
    [calculate_user_voting_power]
    calculte the voting power of one user.
*)
let calculate_user_voting_power (
    token, base_tok, reputation, base_rep, fidelity, base_fid :
    nat * nat * nat * nat * nat * nat) : nat =
    (token + base_tok) * (reputation + base_rep) * (fidelity + base_fid)


(**
    [count (votes)] is the count of [votes].
    The count is a triple of total votes (yay + nay),
    sum of votes yay,
    and sum of votes nay.
*)
let count (votes, base_tok, base_rep, base_fid, user_score 
    : votes * nat * nat * nat * (address, scores) big_map 
    ) : (nat * nat * nat) =
    let folded =
        fun ((yay, nay), (addr, (choice, vote)) : (nat * nat) * (address * (t))) ->

            let score = match Big_map.find_opt addr user_score with
                None -> failwith Errors.score_do_not_exist
                | Some (s) -> s in

            let voting_power = calculate_user_voting_power(
                vote, base_tok, score.reputation, base_rep, score.fidelity, base_fid) in

            if choice
            then (yay + voting_power, nay)
            else (yay, nay + voting_power) in
    let (yay, nay) = Map.fold folded votes (0n, 0n) in
    (yay + nay, yay, nay)





