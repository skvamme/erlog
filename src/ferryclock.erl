-module(ferryclock).
-export([start/1,init/1,loop/4]).
 
start(Pid) -> P = spawn_link(?MODULE,init,[Pid]), {ok,P}.
 
init(Pid) ->
    io:format("New process: ~p~n", [?MODULE]),
    Port = open_port({spawn, "gs -q -dNOSAFER"}, [{line,127}]), 
    {ok,Erlog} = erlog:new(),
    {ok,Erlog1} = erlog:consult("examples/ferry.pl", Erlog),
    port_command(Port, "(examples/header.eps) run\n"),
    {{succeed, [{'X', X}]}, _} = erlog:prove({ferryname,{'X'}},Erlog1),
    X1 = atom_to_list(X),
    Pstr = io_lib:format("~s~s~s\n",["/Helvetica 15 selectfont -75 150 moveto (",X1," Ferry Clock) show"]),
    port_command(Port, Pstr),
    self() ! {tick},
    timer:send_interval(1000, {tick}),
    timer:send_interval(100, {tack}),
    loop(Pid,Port,Erlog1,0).

loop(Pid,Port,Erlog,Millisec) ->
    receive
        {tack} -> Pstr = io_lib:format("newpath 0 0 88 90 ~p arcn stroke\n",[90 - (Millisec * 0.6)]), 
		port_command(Port,Pstr),
		Millisec1 = case Millisec of
			X when X >= 600 -> 0;
			X -> X + 1 
		end,
            ?MODULE:loop(Pid,Port,Erlog,Millisec1);
        {tick} -> {{Y,Mo,D},{H,Mi,S}} = calendar:local_time(),
            Day = calendar:day_of_the_week({Y,Mo,D}),
            Seconds_after_midnight = calendar:time_to_seconds({H,Mi,S}),
            Minutes_after_midnight = Seconds_after_midnight div 60,
            case Seconds_after_midnight rem 60 of                           % On a full minute, hands should move (rem = 0)
                0 -> N = case  erlog:prove({next_ferry,Day,Minutes_after_midnight,{'X'}}, Erlog) of
                    {{succeed, [{'X', X}]}, _} -> X;
                    _ -> io:format("Fail_1: ~p ~p ~p~n",[H,Mi,S]), -1
                    end,
                    N1 = case  erlog:prove({next_ferry,Day,Minutes_after_midnight + N + 1,{'Z'}}, Erlog) of
                    {{succeed, [{'Z', Z}]}, _} -> Z;
                    _ -> io:format("Fail_2: ~p ~p ~p~n",[H,Mi,S]), -1
                    end,
                    Pstr = io_lib:format("del clockface ~p ~p newhour minute ~p nextferry ~p thereafter 0.5 setgray 2 setlinewidth\n",[H,Mi,N,N + N1 +1]),
                    port_command(Port, Pstr),
                    Millisec1 = 0;
                _ -> Millisec1 = Millisec
            end,
            ?MODULE:loop(Pid,Port,Erlog,Millisec1);
        _Any ->  % io:format("~p got unknown msg: ~p~n",[?MODULE, _Any]),
            ?MODULE:loop(Pid,Port,Erlog,Millisec)
    end.

