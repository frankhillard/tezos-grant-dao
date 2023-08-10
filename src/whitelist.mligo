#import "./errors.mligo" "Errors"

type tzprofile = string
type requests = (address, tzprofile) map
type members = (address, tzprofile) map

// (**
//     [is_member(p, s)] is an on-chain view to see if a user is a member
//     Raises [Errors.] if ................
// *)
// [@view]
// let is_member(seek_address : address)(s : Storage.t) : bool =
//     match Map.find_opt(seek_address store.members) with
//         | None -> False
//         | Some (_) -> True
