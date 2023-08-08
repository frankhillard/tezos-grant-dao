#import "@ligo/fa/test/helpers/list.mligo" "List_helper"
#import "./helpers/token.mligo" "Token_helper"
#import "./helpers/dao.mligo" "DAO_helper"
#import "./helpers/suite.mligo" "Suite_helper"
#import "./helpers/log.mligo" "Log"
#import "./helpers/assert.mligo" "Assert"
#import "./bootstrap/bootstrap.mligo" "Bootstrap"
#import "../src/main.mligo" "DAO"

let () = Log.describe("[Execute] test suite")

(* Boostrapping of the test environment, *)
let init_tok_amount = 100_000_000n
let bootstrap (init_dao_storage : DAO.storage) =
    Bootstrap.boot(init_tok_amount, init_dao_storage)
let base_config = DAO_helper.base_config
let base_storage = DAO_helper.base_storage

(* Successful timelock execution of an operation list *)
let test_success =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_delay = 10n; } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    let lambda_ = Some(( DAO_helper.empty_op_list_hash, OperationList)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, 25n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let _r = DAO_helper.execute(1n, DAO_helper.empty_op_list_packed, dao.contr) in
    DAO_helper.assert_executed(dao.taddr, 1n)

(* Successful execution of a parameter change *)
let test_success_parameter_changed =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_delay = 10n; } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    let base_config = DAO_helper.base_config in
    let packed = Bytes.pack (fun() -> { base_config with super_majority = 82n }) in
    let lambda_ = Some((Crypto.sha256 packed, ParameterChange)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, 25n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let _r = DAO_helper.execute(1n, packed, dao.contr) in
    let () = DAO_helper.assert_executed(dao.taddr, 1n) in
    let dao_storage = Test.get_storage dao.taddr in

    (* Assert that the config has been updated *)
    assert(dao_storage.config.super_majority = 82n)

(* Successful execution of an operation list *)
let test_success_operation_list =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_delay = 10n; } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    let owner2 = List_helper.nth_exn 2 tok.owners in
    let owner2_initial_balance = Token_helper.get_balance_for(tok.taddr, owner2) in

    (* Pack an operation that will send 2 tokens from DAO to owner2 *)
    let owner2_amount_to_receive = 2n in
    let packed = Token_helper.pack_transfer(tok.addr, dao.addr, owner2,
    owner2_amount_to_receive) in

    let owner2_amount_locked = 25n in
    let lambda_ = Some((Crypto.sha256 packed, OperationList)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, owner2_amount_locked, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let _r = DAO_helper.execute(1n, packed, dao.contr) in
    let () = DAO_helper.assert_executed(dao.taddr, 1n) in

    let owner2_expected_balance : nat = abs(
        owner2_initial_balance
        - owner2_amount_locked
        + owner2_amount_to_receive)
    in
    Token_helper.assert_balance_amount(tok.taddr, owner2, owner2_expected_balance)

(* Failing because no outcome *)
let test_failure_no_outcome =
    let (_tok, dao, sender_) = bootstrap(base_storage) in
    let () = Test.set_source sender_ in

    let r = DAO_helper.execute(1n, DAO_helper.dummy_packed, dao.contr) in
    Assert.string_failure r DAO.Errors.outcome_not_found

(* Failing because timelock delay not elapsed *)
let test_failure_timelock_delay_not_elapsed =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_delay = 1800n } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    let lambda_ = Some((DAO_helper.dummy_hash, ParameterChange)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, 25n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let r = DAO_helper.execute(1n, DAO_helper.dummy_packed, dao.contr) in
    Assert.string_failure r DAO.Errors.timelock_locked

(* Failing because timelock has been relocked *)
let test_failure_timelock_relocked =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_period = 10n } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    let lambda_ = Some(( DAO_helper.empty_op_list_hash, OperationList)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, 25n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let r = DAO_helper.execute(1n, DAO_helper.empty_op_list_packed, dao.contr) in
    Assert.string_failure r DAO.Errors.timelock_locked

(* Failing because the packed data is not matching *)
let test_failure_lambda_wrong_packed_data =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_delay = 10n; } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    let lambda_ = Some((DAO_helper.dummy_hash, ParameterChange)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, 25n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let r = DAO_helper.execute(1n, DAO_helper.dummy_packed, dao.contr) in
    Assert.string_failure r DAO.Errors.lambda_wrong_packed_data

(* Failing because the lambda couldn't be unpacked because of wrong lambda kind *)
let test_failure_wrong_lambda_kind =
    let config = { base_config with
        start_delay = 10n;
        voting_period = 400n;
        timelock_delay = 10n; } in
    let dao_storage = { base_storage with config = config } in
    let (tok, dao, sender_) = bootstrap(dao_storage) in
    let () = Test.set_source sender_ in

    (* the lambda kind is ParameterChange but it should have been OperationList *)
    let lambda_ = Some( (DAO_helper.empty_op_list_hash, ParameterChange)) in
    let votes = [(0, 25n, true); (1, 25n, true); (2, 25n, true)] in
    let () = Suite_helper.create_and_vote_proposal(tok, dao, lambda_, votes) in

    let r = DAO_helper.execute(1n, DAO_helper.empty_op_list_packed, dao.contr) in
    Assert.string_failure r DAO.Errors.wrong_lambda_kind
