# Description — Separate Wallet for promo (RW-1991)

> UPDATED 2026-06-29T14:56 by Mohamed Elsabry (PO). The fixed-index requirement was struck
> through. Current wording: "The wallet should be ~~in index 10,000 (or any other index)~~
> **marked with Promo and can be created at next available index**." Confirmed in his
> 14:54 comment: "marked with Promo and can be created at next available index."
> Net: the promo wallet is identified by its `Promo` type, derived at the next available
> account index (NOT pinned to 10,000); the index and details are still stored in BE.

Create a wallet for all users, this wallet is called promo wallet.
The wallet should be ~~in index 10,000 (or any other index)~~ marked with Promo and can be created at next available index.
The wallet index and its details should be stored in BE.
This wallet should have a `Promo` type in BE.

Funds in this wallet can only be used for Tipping, in the Send Tip flow. This wallet shouldn't be enabled in Send, receive, Buy, Swap, Cashout. Only Send Tip.

Disable all buttons of all functions that don't work in this wallet.

This wallet only show up in tipping flow when the user want to tip
