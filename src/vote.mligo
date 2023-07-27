type choice = bool
type t = (choice * nat)
type votes = (address, t) map

(**
    [count (votes)] is the count of [votes].
    The count is a triple of total votes (for + againt),
    sum of votes for_,
    and sum of votes against_.
*)
let count (votes : votes) : (nat * nat * nat) =
  let folded =
    fun ((for_, against_), (_, (choice, vote)) : (nat * nat) * (address * (t))) ->
      if choice
      then (for_ + vote, against_)
      else (for_, against_ + vote) in
  let (for_, against_) = Map.fold folded votes (0n, 0n) in
  (for_ + against_, for_, against_)
