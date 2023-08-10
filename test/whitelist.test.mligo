#import "./helpers/token.mligo" "Token_helper"
#import "./helpers/dao.mligo" "DAO_helper"
#import "./helpers/log.mligo" "Log"
#import "./helpers/assert.mligo" "Assert"
#import "./bootstrap/bootstrap.mligo" "Bootstrap"
#import "../src/main.mligo" "DAO"

let () = Log.describe("[Whitelist] test suite")

(* Boostrapping of the test environment, *)
let init_tok_amount = 10n
let bootstrap() = Bootstrap.boot(init_tok_amount, DAO_helper.base_storage)

(* Successful Access Request *)
let test_successful_access_request =
    let (_tok, dao, sender_) = bootstrap() in

    let dao_storage = Test.get_storage dao.taddr in
    let expected_members = Map.literal[(sender_, "")] in
    let () = assert(dao_storage.requests = (Map.empty : DAO.Whitelist.requests)) in
    let () = assert(dao_storage.members = expected_members) in

    let new_member = Test.nth_bootstrap_account 2 in
    let () = Test.set_source new_member in
    let r = DAO_helper.submit_access_request("tzprofile", dao.contr) in
    let () = Assert.tx_success r in

    let dao_storage = Test.get_storage dao.taddr in
    let () = assert(dao_storage.requests = Map.literal[(new_member, "tzprofile")]) in
    assert(dao_storage.members = expected_members)

(* Successful Access Request *)
let test_successful_access_request_accepted =
    let (_tok, dao, sender_) = bootstrap() in

    let dao_storage = Test.get_storage dao.taddr in
    let expected_members = Map.literal[(sender_, "")] in
    let () = assert(dao_storage.requests = (Map.empty : DAO.Whitelist.requests)) in
    let () = assert(dao_storage.members = expected_members) in

    let new_member = Test.nth_bootstrap_account 2 in
    let () = Test.set_source new_member in
    let r = DAO_helper.submit_access_request("tzprofile", dao.contr) in
    let () = Assert.tx_success r in

    let dao_storage = Test.get_storage dao.taddr in
    let () = assert(dao_storage.requests = Map.literal[(new_member, "tzprofile")]) in
    assert(dao_storage.members = expected_members)

(* Failing Access Request because the request is a duplicate *)
let test_failure_access_request_already_exists =
    let (_tok, dao, sender_) = bootstrap() in

    let dao_storage = Test.get_storage dao.taddr in
    let expected_members = Map.literal[(sender_, "")] in
    let () = assert(dao_storage.requests = (Map.empty : DAO.Whitelist.requests)) in
    let () = assert(dao_storage.members = expected_members) in

    let new_member = Test.nth_bootstrap_account 2 in
    let () = Test.set_source new_member in
    let r = DAO_helper.submit_access_request("tzprofile", dao.contr) in
    let () = Assert.tx_success r in

    let dao_storage = Test.get_storage dao.taddr in
    let () = assert(dao_storage.requests = Map.literal[(new_member, "tzprofile")]) in
    let () = assert(dao_storage.members = expected_members) in

    let () = Test.set_source sender_ in
    let r = DAO_helper.accept_access_request(new_member, dao.contr) in
    let () = Assert.tx_success r in

    let expected_members = Map.literal[(sender_, ""); (new_member, "tzprofile")] in
    let dao_storage = Test.get_storage dao.taddr in
    let () = assert(dao_storage.requests = (Map.empty : DAO.Whitelist.requests)) in
    assert(dao_storage.members = expected_members)


(* Failing Access Request because the applicant is already a member *)
let test_failure_access_request_already_a_member =
    let (_tok, dao, sender_) = bootstrap() in

    let dao_storage = Test.get_storage dao.taddr in
    let expected_members = Map.literal[(sender_, "")] in
    let () = assert(dao_storage.requests = (Map.empty : DAO.Whitelist.requests)) in
    let () = assert(dao_storage.members = expected_members) in

    let new_member = Test.nth_bootstrap_account 2 in
    let () = Test.set_source new_member in
    let r = DAO_helper.submit_access_request("tzprofile", dao.contr) in
    let () = Assert.tx_success r in

    let dao_storage = Test.get_storage dao.taddr in
    let () = assert(dao_storage.requests = Map.literal[(new_member, "tzprofile")]) in
    let () = assert(dao_storage.members = expected_members) in

    let () = Test.set_source sender_ in
    let r = DAO_helper.accept_access_request(new_member, dao.contr) in
    let () = Assert.tx_success r in

    let r = DAO_helper.submit_access_request("tzprofile", dao.contr) in
    Assert.string_failure r DAO.Errors.already_a_member

(* Failing Access Request because the request does not exist *)
let test_failure_access_request_nonexistant_request =
    let (_tok, dao, sender_) = bootstrap() in

    let dao_storage = Test.get_storage dao.taddr in
    let expected_members = Map.literal[(sender_, "")] in
    let () = assert(dao_storage.requests = (Map.empty : DAO.Whitelist.requests)) in
    let () = assert(dao_storage.members = expected_members) in

    let new_member = Test.nth_bootstrap_account 2 in
    let () = Test.set_source new_member in
    let r = DAO_helper.submit_access_request("tzprofile", dao.contr) in
    let () = Assert.tx_success r in

    let dao_storage = Test.get_storage dao.taddr in
    let () = assert(dao_storage.requests = Map.literal[(new_member, "tzprofile")]) in
    let () = assert(dao_storage.members = expected_members) in

    let () = Test.set_source sender_ in
    let r = DAO_helper.accept_access_request(sender_, dao.contr) in
    Assert.string_failure r DAO.Errors.request_does_not_exist
