open Batteries
open Option
open List
open Lnp
open Language
open Substitution
open Pretty_printer_lnp

(* 
	takes fpl_cbv and a theorem schema.
    on fpl_cbv: goes to the 3rd category, which is Value, takes the 3rd operator, which is "pair" 
	and sets the name of the theorem as "pair"
*)
let unusedVar = "_unused_"

let evalExp_of_formula (f: formula): evaluatedExpression = Formula f

type eval_result = 
	| Term of evaluatedExpression
	| ListOfTerms of evaluatedExpression list
	| Number of int 
	| Boolean of bool


let eval_getTerm (Term(evaluatedExpression)) : evaluatedExpression = evaluatedExpression
let eval_getNumber (Number(n)) : int = n
let eval_getBoolean (Boolean(b)) : bool = b
let eval_getListOfTerms (ListOfTerms(l)) = l 
	
let rec eval lan evaluatedExpression : eval_result = match evaluatedExpression with 
	| Var(var2) -> Term(Var(var2)) (* Vars of LNP should already been substituted, but formula's such as forall e, .. (value e) are still there)) *)
	| Num(n) -> Number(n)
	| Name(cname) -> ListOfTerms (List.map langConstructor_to_LNPConstructor (language_grammarLookupByCategory lan cname))
	| Constructor(cname, ts) -> Term (Constructor(cname, ts)) (* no need to have nested terms, just variables suffice. List.map eval_getTerm (List.map (eval lan) ts)) *)
	| ValuesOf(t) -> ListOfTerms (List.map langConstructor_to_LNPConstructor (language_getValuesByType lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| ValueArgs(t) -> ListOfTerms (List.map langConstructor_to_LNPConstructor (language_getValueArgs lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| OfType(t) -> Term (langConstructor_to_LNPConstructor (language_getTypeByOp lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| IsVar(t) -> Boolean (term_isVar (eval_getTerm (eval lan t)) || term_isSubstitution (eval_getTerm (eval lan t)))
	| IsSingleValue(t) -> Boolean (List.length (eval_getListOfTerms (eval lan (ValuesOf(t)))) <= 1)
	| TargetV(t) -> ListOfTerms (List.map langConstructor_to_LNPConstructor (language_getTargetValuesFromVars lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| TargetOp(t) -> ListOfTerms (List.map langConstructor_to_LNPConstructor (language_getTargetValuesFromOp lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| ContainsSub(t) -> Boolean (term_constains_substitution (eval_getTerm (eval lan t)))
	| EvaluationOrder(t) -> ListOfTerms (List.map numberToNumTerm (language_getEvaluationOrderForOp lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| ContextualArgs(t) -> ListOfTerms (List.map numberToNumTerm (language_getContextualArgs lan (term_getConstructorName (eval_getTerm (eval lan t)))))
	| GetArgs(t1, t2) -> Term (term_getNthArg (eval_getTerm (eval lan t1)) (eval_getNumber (eval lan t2)))
	| IsEliminationForm(t) -> Boolean (language_isEliminationForm lan (term_getConstructorName (eval_getTerm (eval lan t))))
	| IsErrorHandler(t) -> Boolean (language_isErrorHandler lan (term_getConstructorName (eval_getTerm (eval lan t))))
	| GetArgType(t1, t2) -> let typeTermFromLanguage = (language_getTypeOfNthArg lan (term_getConstructorName (eval_getTerm (eval lan t1))) (eval_getNumber (eval lan t2)))
								in Term (langConstructor_to_LNPConstructor typeTermFromLanguage)
	| InList(t1, t2) -> Boolean (term_list_mem (eval_getTerm (eval lan t1)) (eval_getListOfTerms (eval lan t2)))
	| IS(t1, t2) -> (Boolean (term_list_mem_upToNumbers (eval_getTerm (eval lan t1)) (eval_getListOfTerms (eval lan t2))))  
	| EqualTerm(t1, t2) -> (match (eval lan t1),(eval lan t2)  with 
							| Term(Constructor(cname1, _)), Term(Constructor(cname2, _)) -> Boolean (cname1 = cname2)
							| Number(n1), Number(n2) -> Boolean (n1 = n2) 
							| _ -> Boolean false )
	| OrTerm(t1, t2) -> Boolean (eval_getBoolean (eval lan t1) || eval_getBoolean (eval lan t2))
	| AndTerm(t1, t2) -> Boolean (eval_getBoolean (eval lan t1) && eval_getBoolean (eval lan t2))
    | Dot(t, Relation(pred)) ->
        let name = term_getConstructorName (eval_getTerm (eval lan t)) in
        let rules = List.filter (rule_isPredname pred) (language_getRulesOfOp lan name) in
        Term (Rule (List.hd rules))
    | Dot(Rule r, Num n) -> Term (langConstructor_to_LNPConstructor (List.nth (formula_getArguments (rule_getConclusion r)) n))
    | Dot(Rule r, Premises(None)) -> ListOfTerms (List.map evalExp_of_formula (rule_getPremises r))
    | Dot(Premise(i, p), Num n) -> Term (langConstructor_to_LNPConstructor (List.nth (formula_getArguments p) n))
    | Dot(t, Premises(Some(predname))) ->
        let (Lnp.Rule r) = (eval_getTerm (eval lan t)) in
        let premises = (rule_getPremises r) in
        ListOfTerms (
            (List.filter
                (fun (Premise(i, p)) -> formula_getPredname p = predname)
                (List.mapi (fun i p -> Premise(i, p)) premises)))
    | Dot(t, PremisesIdx predname) ->
        let (Lnp.Rule r) = (eval_getTerm (eval lan t)) in
        let premises = (rule_getPremises r) in
        ListOfTerms (List.map numberToNumTerm
            (List.filter
                (fun i -> formula_getPredname (List.nth premises i) = predname)
                (List.mapi (fun i _ -> i) premises)))
    | Rule(_) | Formula(_) -> Term(evaluatedExpression)
    | Align(t1, t2, Num n1, Num n2) ->
        let (Lnp.Rule(r1)) = eval_getTerm (eval lan t1) in
        let (Lnp.Rule(r2)) = eval_getTerm (eval lan t2) in
        let conc1 = rule_getConclusion r1 in
        let conc2 = rule_getConclusion r2 in
        let t1 = List.nth (formula_getArguments conc1) n1 in
        let t2 = List.nth (formula_getArguments conc2) n2 in
        let substs = constr_unify t1 t2 in
        Term (Rule (List.fold_left (fun rule (var, term) -> rule_substitution rule var term) r1 substs))
    | Append(t1, t2) ->
        let left = eval_getListOfTerms (eval lan t1) in
        let right = eval_getListOfTerms (eval lan t2) in
        ListOfTerms (left @ right)
    | Covariant(t1, t2) ->
        let i = eval_getNumber (eval lan t1) in
        let ty = term_getConstructorName (eval_getTerm (eval lan t2)) in
        let category = if language_grammarCatagoryExists lan "Subtyping" then "Subtyping" else "SubtypingA" in
        let subtyping = language_grammarLookupByCategory lan category in
        let ty_constr = List.find (fun (Constr(cname, _)) -> cname = ty) subtyping in
        let LangVar(variance) = List.nth (term_getArguments ty_constr) i in
        Boolean (String.starts_with variance "Cov" || String.starts_with variance "AbsCov")
    | FindVarInPremises(t1, t2) -> begin
        let var = List.hd (term_getVars (eval_getTerm (eval lan t1))) in
        let premises = List.map (fun (Premise(i, p)) -> p) (eval_getListOfTerms (eval lan t2)) in
        match (formulaFind var premises) with
        | Some(lst) -> ListOfTerms(lst)
        | None -> raise (Failure (var ^ " not found"))
    end
    | FindSucceeds(t1, t2) -> begin
        let t1 = eval_getTerm (eval lan t1) in
        let t2 = eval_getListOfTerms (eval lan t2) in
        match t1 with
        | Var var ->
            let premises = List.map (fun (Premise(i, p)) -> p) t2 in
            Boolean(Option.is_some (formulaFind var premises))
        | _ -> Boolean false
    end
    | VarsOf(t1) ->
        let e = eval_getTerm (eval lan t1) in
        ListOfTerms (List.map (fun v -> Var v) (term_getVars e))
    | TargetOfElimForm(t1, t2) | TargetOfErrorHandler(t1, t2) ->
        let elim = (term_getConstructorName (eval_getTerm (eval lan t1))) in
        let value = (term_getConstructorName (eval_getTerm (eval lan t2))) in
        Term (langConstructor_to_LNPConstructor (tmp_name_fix lan elim value))
    | HasEnvType(t1) ->
        let e = eval_getTerm (eval lan t1) in
        Boolean (is_some (formulaEnvType e))
    | EnvType(t1) ->
        let e = eval_getTerm (eval lan t1) in
        Term (langConstructor_to_LNPConstructor (Option.get (formulaEnvType e)))
    | Range(t1) ->
        let Num n = eval_getTerm (eval lan t1) in
        ListOfTerms (List.init n (fun i -> Num i))
    | Arity(t1) ->
        let Constructor (_, args) = eval_getTerm (eval lan t1) in
        Term (Num (List.length args))
    | ListDifference(t1, t2) ->
        let left = eval_getListOfTerms (eval lan t1) in
        let right = eval_getListOfTerms (eval lan t2) in
        let diff = list_difference left right in
        ListOfTerms (diff)
    | Premise _ -> Term (evaluatedExpression)

let hypParamAsStr arg = match arg with
    | Var("_") -> "0"
    | Premise(i, _) -> string_of_int i
    | Num(n) -> string_of_int n

let compile_lnp_name lan lnp_name = match lnp_name with 
	| SuffixedString(str, evaluatedExpression) -> let suffix = (match eval lan evaluatedExpression with 
														| Term((Constructor(cname, ts))) -> cname
														| Number(n) -> string_of_int n
														| _ -> "Wrong term computed as suffix to append to a name")
													in String (str ^ suffix)
    | Function(name, args) ->
        String(name ^ "-" ^ (String.concat "-" (List.map hypParamAsStr args)))
    | ApplyFromList(name, evaluatedExpression) ->
        let args = eval_getListOfTerms (eval lan evaluatedExpression) in
        String(name ^ "-" ^ (String.concat "-" (List.map hypParamAsStr args)))
	| _ -> lnp_name
	
let rec compile_formula lan formula = match formula with 
	| Top -> Top
	| Bottom -> Bottom
	| Formula(lnp_name, predname, ts) -> Formula(compile_lnp_name lan lnp_name, predname, List.map eval_getTerm (List.map (eval lan) ts))
	| Forall(var2, formula) -> Forall(var2, compile_formula lan formula)
	| Exists(var2, formula) -> Exists(var2, compile_formula lan formula)
	| ForallVars(t, formula) -> makeForall (term_getVars (eval_getTerm (eval lan t))) (compile_formula lan formula)
	| ExistsVars(t, formula) -> makeExists (term_getVars (eval_getTerm (eval lan t))) (compile_formula lan formula)
	| EqualFormula(t1, t2) -> EqualFormula(eval_getTerm (eval lan t1), eval_getTerm (eval lan t2))
	| OrMacro(var2, t, formula) -> let formulaeInstantiated = List.map (substitution_formula formula var2) (eval_getListOfTerms (eval lan t)) in makeOr (List.map (compile_formula lan) formulaeInstantiated)
	| AndMacro(var2, t, formula) -> let formulaeInstantiated = List.map (substitution_formula formula var2) (eval_getListOfTerms (eval lan t)) in makeAnd (List.map (compile_formula lan) formulaeInstantiated)
	| ImplyMacro(var2, t, formula) -> let formulaeInstantiated = List.map (substitution_formula formula var2) (eval_getListOfTerms (eval lan t)) in makeImply (List.map (compile_formula lan) formulaeInstantiated)
	| Imply(formula1, formula2) ->  if compile_formula lan formula2 = Top then compile_formula lan formula1 else Imply(compile_formula lan formula1, compile_formula lan formula2)
	| And(formula1, formula2) -> if compile_formula lan formula2 = Top then compile_formula lan formula1 else And(compile_formula lan formula1, compile_formula lan formula2)
	| Or(formula1, formula2) -> if compile_formula lan formula2 = Bottom then compile_formula lan formula1 else Or(compile_formula lan formula1, compile_formula lan formula2)
    | ExistStar(formula) -> ExistStar(compile_formula lan formula)
    | ForallStar(formula) -> ForallStar(compile_formula lan formula)
    | Let(var, t, formula) -> compile_formula lan (substitution_formula formula var (eval_getTerm (eval lan t)))

(* expect formula is already compiled *)
let rec expand_some_stars ?(bound_vars = []) formula =
    match formula with
	| Top -> Top
	| Bottom -> Bottom
	| Formula(lnp_name, predname, ts) -> formula
	| Forall(var2, formula) -> Forall(var2, expand_some_stars ~bound_vars:(var2 :: bound_vars) formula)
	| Exists(var2, formula) -> Exists(var2, expand_some_stars ~bound_vars:(var2 :: bound_vars) formula)
	| ForallVars(t, formula) -> assert false
	| ExistsVars(t, formula) -> assert false
	| EqualFormula(t1, t2) -> formula
	| OrMacro(var2, t, formula) -> assert false
	| AndMacro(var2, t, formula) -> assert false
	| ImplyMacro(var2, t, formula) -> assert false
	| Imply(formula1, formula2) -> Imply(expand_some_stars ~bound_vars formula1, expand_some_stars ~bound_vars formula2)
	| And(formula1, formula2) -> And(expand_some_stars ~bound_vars formula1, expand_some_stars ~bound_vars formula2)
	| Or(formula1, formula2) -> Or(expand_some_stars ~bound_vars formula1, expand_some_stars ~bound_vars formula2)
    | ExistStar(formula) -> makeExists (list_difference (formula_free_vars formula) bound_vars) formula
    | ForallStar(formula) -> makeForall (list_difference (formula_free_vars formula) bound_vars) formula
    | Let(var, t, formula) -> assert false
    | FVar(var) -> assert false

let rec expand_stars formula =
    let expanded = expand_some_stars formula in
    if expanded = formula then
        formula
    else
        expand_stars expanded
	
let rec compile_proof lan names ctx proof = match proof with 
| Intros c -> Intros(c ^ ctx)
| Search c -> Search (c ^ ctx)
| NoOp -> NoOp
| Skip -> Skip
| Case(c, lnp_name1, lnp_name2) -> Case((c ^ ctx), compile_lnp_name lan lnp_name1, compile_lnp_name lan lnp_name2)
| CaseStar(lnp_name1, lnp_name2, proof) -> NoOp
| Induction(lnp_name1, lnp_name2) -> Induction(compile_lnp_name lan lnp_name1,compile_lnp_name lan lnp_name2)
| MutualInduction(lnp_name1, lnp_name2, lnp_name3, proof1, proof2) -> MutualInduction(compile_lnp_name lan lnp_name1, compile_lnp_name lan lnp_name2, compile_lnp_name lan lnp_name3, compile_proof lan names ctx  proof1, compile_proof lan names ctx proof2)
| InductionStar(lnp_name1, lnp_name2, proof) -> NoOp
| Apply(c, lnp_name1, lnp_name2, lnp_names, inst) -> Apply((c ^ ctx), compile_lnp_name lan lnp_name1, compile_lnp_name lan lnp_name2, List.map (compile_lnp_name lan) lnp_names, inst)
| Backchain(c, lnp_name) -> Backchain((c ^ ctx), compile_lnp_name lan lnp_name)
| If(c, t, proof1, proof2) ->(* let _ = (raise (Failure "if encountered")) in *) if eval_getBoolean (eval lan t) then compile_proof lan names (ctx ^ "-IF:" ^ c ^ ":" ^ print_evalExp t ) proof1 else compile_proof lan names (ctx ^ "-IF:" ^ c ^":" ^ "NOT(" ^  print_evalExp t ^ ")") proof2
(*| ForEachProof(x, l, proof) -> makeSeq (List.map (compile_proof lan names (ctx ^ "-FOR:")) (List.map (substitution_proof proof x) (eval_getListOfTerms (eval lan l))))*)
| Seq(proof1, proof2) -> if compile_proof lan names ctx proof1 = NoOp then compile_proof lan names ctx proof2 else Seq(compile_proof lan names ctx proof1, compile_proof lan names ctx proof2)
| ForEachProof(c, x, l, proof) -> 
    makeSeq (lToAnnProofs (eval_getListOfTerms (eval lan l)) lan names x c ctx proof)
and lToAnnProofs (lst : evaluatedExpression list) lan names (var : string) (c : string) (ctx : string) (proof : proof) : proof list =
  if lst = [] then []
  else
    let head = List.hd lst in
    let substituted_proof = substitution_proof proof var head in
    let compiled_proof = compile_proof lan names (ctx ^ "-FOR:" ^ c ^ ":" ^ print_evalExp head ) substituted_proof in
    compiled_proof :: lToAnnProofs (List.tl lst) lan names var c ctx proof

let compileInstantiated lan schema = 
	ForEachThm(None,
        compile_lnp_name lan (schema_getTheoremName schema),
        expand_stars (compile_formula lan (schema_getTheorem schema)),
        compile_proof lan (map_names_formulae_in_theorem (schema_getTheorem schema)) "" (schema_getProof schema))
	
let compile lan schema : schema list = 
	let (var, substList) : (string * (evaluatedExpression list)) = 
		if is_none (schema_getIteration schema) then (unusedVar, [Var "Just one element list"]) (* This is an ineffectul substitution, will create ONE version of the theorem *)
			else let (var, t) =  get (schema_getIteration schema) in (var, (eval_getListOfTerms (eval lan t)))
														(* substitution_schema also removes the Iteration part of the theorem (for each ...)  *)
		in List.map (compileInstantiated lan) (List.map (substitution_schema schema var) substList)
	
	
let testManipulation lan schema = 
	match lan with Language(g1 :: g2 :: g3 :: rest, _) -> 
		match schema with ForEachThm(ite, lnp_name, formula, proof) -> 
			match g3 with GrammarLine(category, metavar, items) -> 
				match List.nth (Option.get items) 2 with Constr(opname,ts) -> 
					ForEachThm(ite, String opname, formula, proof) 

	(*	| Imply(formula1, formula2) ->  Imply(compile_formula lan formula1, compile_formula lan formula2)
		| And(formula1, formula2) -> And(compile_formula lan formula1, compile_formula lan formula2)
		| Or(formula1, formula2) -> Or(compile_formula lan formula1, compile_formula lan formula2)
	*)
