-module(mzb_ast).

-export([transform/1, add_meta/2, map_meta/2, fold/3]).

-include("mzb_types.hrl").
-include("mzb_ast.hrl").

-spec add_meta(abstract_expr(), meta()) -> abstract_expr().
add_meta(Expr, NewMeta) ->
    map_meta(fun (Meta, _) -> Meta ++ NewMeta end, Expr).

-spec map_meta(fun((meta(), atom()) -> meta()), abstract_expr()) -> abstract_expr().
map_meta(Fun, #operation{name = Name, meta = Meta, args = Args} = Op) ->
    Op#operation{meta = Fun(Meta, Name), args = map_meta(Fun, Args)};
map_meta(Fun, L) when is_list(L) -> lists:map(fun(X) -> map_meta(Fun, X) end, L);
map_meta(_, C) -> C.

fold(Fun, Acc, #operation{args = Args} = Op) ->
    fold(Fun, Fun(Op, Acc), Args);
fold(Fun, Acc, L) when is_list(L) ->
    lists:foldl(fun(X, Acc2) -> fold(Fun, Acc2, X) end, Acc, L);
fold(Fun, Acc, C) ->
    Fun(C, Acc).

-spec markup(abstract_expr()) -> abstract_expr().
markup({tuple, Line, [{atom, L2, Op} | Params]}) ->
    {tuple, Line, [{atom, L2, Op}, {cons, L2, {tuple, L2, [{atom, L2, line}, {integer, L2, Line}]}, {nil, L2}} |
                 markup(Params)]};
markup({tuple, Line, [{tuple, _, _} = S | T]}) ->
    {tuple, Line, [markup(S) | T]};
markup({tuple, Line, []}) ->
    {tuple, Line, [{cons, Line, {tuple, Line, [{atom, Line, line}, {integer, Line, Line}]}, {nil, Line}}]};

markup(L) when is_list(L) -> lists:map(fun markup/1, L);
markup(T) when is_tuple(T) ->
    case tuple_to_list(T) of
        [cons, L | S] -> list_to_tuple([cons, L | markup(S)]);
        _ -> T
    end;
markup(S) -> S.

-spec records(term()) -> term().
records(L) when is_list(L) -> lists:map(fun records/1, L);
records(T) when is_tuple(T) ->
    case tuple_to_list(T) of
        [N, Units] when is_number(N) -> #constant{value = N, units = Units};
        % FIXME: this doesn't handle {var, {{var, "name"}, float}}
        [VarName, VarType] when is_list(VarName) -> {VarName, VarType};
        [T2, Units] when is_tuple(T2) -> #constant{value = records(T2), units = Units};
        [ramp, Meta, CurveType, From, To] ->
            #ramp{curve_type = CurveType,
                  from = records(From),
                  to = records(To),
                  meta = Meta};
        [Name, Meta | Params] ->
            IsStd = mzb_stdlib:is_std_function(Name, length(Params)),
            #operation{
                name = Name,
                meta = Meta,
                args = records(Params),
                is_std = IsStd};
        [Meta] -> #operation{name = undefined, meta = Meta, args = []}
    end;
records(S) -> S.

-spec transform(abstract_expr()) -> term().
transform(AST) ->
    records(erl_parse:normalise(markup(AST))).

