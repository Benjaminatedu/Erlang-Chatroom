-module(bank_account).
-export([start/0, create_account/2, deposit/2, withdraw/2, balance/1]).

start() ->
    spawn(fun() -> bank_loop([]) end).

bank_loop(Accounts) ->
    receive
        {create_account, AccountNumber, InitialBalance} ->
            NewAccount = {AccountNumber, InitialBalance},
            bank_loop([NewAccount | Accounts]);

        {deposit, AccountNumber, Amount} ->
            UpdatedAccounts = update_account(Accounts, AccountNumber, Amount, deposit),
            bank_loop(UpdatedAccounts);

        {withdraw, AccountNumber, Amount} ->
            UpdatedAccounts = update_account(Accounts, AccountNumber, Amount, withdraw),
            bank_loop(UpdatedAccounts);

        {balance, AccountNumber, Pid} ->
            case find_account(Accounts, AccountNumber) of
                {ok, _, Balance} -> Pid ! {balance, AccountNumber, Balance},
                                    ok;
                not_found -> Pid ! {account_not_found, AccountNumber},
                             ok
            end,
            bank_loop(Accounts);

        {timeout, Pid} ->
            Pid ! {error, timeout},
            bank_loop(Accounts);

        stop ->
            ok
    after
        5000 -> % Timeout after 5 seconds
            bank_loop(Accounts)
    end.

create_account(AccountNumber, InitialBalance) ->
    self() ! {create_account, AccountNumber, InitialBalance}.

deposit(AccountNumber, Amount) ->
    self() ! {deposit, AccountNumber, Amount}.

withdraw(AccountNumber, Amount) ->
    self() ! {withdraw, AccountNumber, Amount}.

balance(AccountNumber) ->
    self() ! {balance, AccountNumber, self()},
    receive
        {balance, AccountNumber, Amount} ->
            io:format("Account ~w balance: ~w~n", [AccountNumber, Amount]),
            ok
    end.

update_account([], _, _, _) -> [];
update_account([{AccountNumber, Balance} | Rest], AccountNumber, Amount, Operation) ->
    UpdatedBalance = case Operation of
        deposit -> Balance + Amount;
        withdraw -> Balance - Amount
    end,
    [{AccountNumber, UpdatedBalance} | update_account(Rest, AccountNumber, Amount, Operation)];
update_account([Account | Rest], AccountNumber, Amount, Operation) ->
    [Account | update_account(Rest, AccountNumber, Amount, Operation)].

find_account([], _) -> not_found;
find_account([{AccountNumber, Balance} | _], AccountNumber) -> {ok, AccountNumber, Balance};
find_account([_ | Rest], AccountNumber) -> find_account(Rest, AccountNumber).
