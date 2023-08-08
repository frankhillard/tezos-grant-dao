#import "@ligo/fa/test/helpers/list.mligo" "List_helper"
#import "./helpers/dao.mligo" "DAO_helper"
#import "./helpers/suite.mligo" "Suite_helper"
#import "./helpers/log.mligo" "Log"
#import "./helpers/assert.mligo" "Assert"
#import "./bootstrap/bootstrap.mligo" "Bootstrap"
#import "../src/main.mligo" "DAO"

let () = Log.describe("[Score] test suite")

(* Boostrapping of the test environment, *)
let init_tok_amount = 100_000_000n
let voting_period = 400n
let bootstrap () =
    let base_config = DAO_helper.base_config in
    let base_storage = DAO_helper.base_storage in
    let config = { base_config with
        start_delay = 10n;
        voting_period = voting_period;
    } in
    let dao_storage = { base_storage with config = config } in
    Bootstrap.boot(init_tok_amount, dao_storage)

(* Successful update the reputation and fidelity with proposal accepted *)
let test_update_score =
    let (tok, dao, sender_) = bootstrap() in

    let lambda_ = Some(( DAO_helper.empty_op_list_hash, OperationList)) in
    let votes = [(0, 25_000_000n, true); (1, 25_000_000n, true); (2, 25_000_000n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let dao_storage = Test.get_storage dao.taddr in
    let sender_score = Option.unopt(Big_map.find_opt sender_ dao_storage.user_score) in
    let () = assert (sender_score.reputation = 1n) in
    assert (sender_score.fidelity >= voting_period)


(* Successful update the fidelity with an unlock *)
let test_update_rep =
    let (_tok, dao, sender_) = bootstrap() in
    let () = Test.set_source sender_ in

    let () = DAO_helper.lock_success(3n, dao.contr) in
    let () = DAO_helper.release_success(3n, dao.contr) in

    let dao_storage = Test.get_storage dao.taddr in
    let sender_score = Option.unopt(Big_map.find_opt sender_ dao_storage.user_score) in
    let () = assert (sender_score.reputation = 0n) in
    assert (sender_score.fidelity  > 0n)
