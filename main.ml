open Batteries
open Unix
open Filename
open Language
open Lnp
open Pretty_printer_lnp
open Pretty_printer_mod
open Pretty_printer_thm
open Compile
(*
open LanguageDef
open Expr_evaluator
open Theorem_evaluator
open Macro_expander
*)
open Lexing
open DeclarationsToRules

let repo_dir = "repo-Debug"

let get_positions lexbuf = let pos = lexbuf.lex_curr_p in pos.pos_fname ^ ":" ^ string_of_int pos.pos_lnum  ^ ":" ^ string_of_int (pos.pos_cnum - pos.pos_bol + 1)
let list_minus_last l = List.rev (List.tl (List.rev l))

let languagesFromRepo = 
	let contents = Array.to_list (Sys.readdir repo_dir) in
	let files =
	  List.fold_left (fun (files) f ->
	       match (stat (repo_dir ^ "/" ^ f)).st_kind with
		   | S_REG -> if String.ends_with f ".lan" then files @ [f] else files (* Regular file *)
	   	   | _ -> files)
		   [] contents in 
		   files

let repoOfSchemas = ref [
(* 

	"./canonical_d1.lnp"
 *)
	"./canonical_d3.lnp"
    
     (* Soundness without subtyping 
	"./canonical.lnp"
	;
	"./progress-op.lnp"
	;
	"./progress.lnp"
	;
    "./error-types-all.lnp"
    ;
	"./preservation.lnp"
    ;
    
*)
    (*
    (* Soundness with only declarative subtyping *)
    "./inversion-subtype.lnp"
    ;
	"./canonical-sub.lnp"
	;
	"./progress-op-sub.lnp"
	;
	"./progress-sub.lnp"
	;
    "./inversion-typing.lnp"
    ;
    "./inversion-error.lnp"
    ;
    "./error-types-all-sub.lnp"
    ;
	"./preservation-sub.lnp"
    ;
    *)

  (*
    (* Equivalence of algorithmic and declaritive subtyping *)
    "./inversion-subtype.lnp"
    ;
    "subtyping-soundness.lnp"
    ;
    "join-and-meet-implies-subtyping.lnp"
    ;
    "join-implies-subtyping.lnp"
    ;
    "typing-soundness.lnp"
    ;
    "subtypingA-transitivity-double.lnp"
    ;
    "subtypingA-transitivity.lnp"
    ;
    "subtypingA-top.lnp"
    ;
    "subtypingA-reflexivity.lnp"
    ;
    "subtyping-complete.lnp"
    ;
    "inversion-subtypeA.lnp"
    ;
    "existence-of-join-and-meet.lnp"
    ;
    "existence-of-join.lnp"
    ;
    "subtyping-transitivity.lnp"
    ;
    "typing-complete.lnp"
    ;
  *)


    (*
    (* Soundness with only algorithmic subtyping *)
	"./canonical.lnp"
	;
	"./progress-op.lnp"
	;
	"./progress.lnp"
	;
    "subtypingA-transitivity-double.lnp"
    ;
    "subtypingA-transitivity.lnp"
    ;
    "subtypingA-reflexivity.lnp"
    ;
    "join-and-meet-implies-subtypingA.lnp"
    ;
    "join-implies-subtypingA.lnp"
    ;
    "error-types-all.lnp"
    ;
    "preservation-subA.lnp"
    ;
    *)

    ]
;;

let parseOneLanguage filename =
  (* Parse the language, lan is the parsed language *)
  let input = (open_in (repo_dir ^ "/" ^ filename)) in
  let filebuf = Lexing.from_channel input in
  let unusedVar = print_endline ("Reading the language: " ^ filename) in 
  let lan = try (ParserLan.fileLan LexerLan.token filebuf) with
						    | LexerLan.Error msg -> raise(Failure(filename ^ ": Lexer error: " ^ get_positions filebuf ^ " with message: " ^ msg))
						    | ParserLan.Error -> raise(Failure(filename ^ ": Parser error: " ^ get_positions filebuf)) in
   let unusedVar = IO.close_in input; in 
      (language_addRules lan (language_subtypeDeclarationsAsRules lan))

let parseTheSchema filename = 
   (* Parse the theorem&proof schema, schema is the var of the parsed schema *)
   let inputSchema = (open_in filename) in
   let filebuf = Lexing.from_channel inputSchema in
   let schema = try (Parser.file Lexer.token filebuf) with
 						    | Lexer.Error msg -> raise(Failure(filename ^ ": Lexer error: " ^ get_positions filebuf ^ " with message: " ^ msg))
 						    | Parser.Error -> raise(Failure(filename ^ ": Parser error: " ^ get_positions filebuf)) in

   let unusedVar = IO.close_in inputSchema; in 
       schema

let parseAllLanguages _ = 
	let _ = List.map parseOneLanguage languagesFromRepo in 
	print_endline "Successfully parsed all languages."

let applySchemaToOneLang schema filenameLan = 
	let lan = parseOneLanguage filenameLan in 
		compile lan schema

let applySchemaToAllLanguages filenameSchema = 	
	let schema = parseTheSchema filenameSchema in 
		List.map (applySchemaToOneLang schema) languagesFromRepo 
let debug_progressesDefinition = "Define progresses : term -> prop by\t progresses E := {value E} ;\t progresses E := {error E} ;\t progresses E := exists E', {step E E'}.\n"
let progressesDefinition = "Define progresses : term -> prop by\n\t progresses E := {value E} ;\n\t progresses E := {error E} ;\n\t progresses E := exists E', {step E E'}.\n\n"
let errorTypesAllTheorem lan = 
	let proofWhenThereAreNoErrors = "Theorem Error-types-all: forall E T1 T2, {typeOf E T1} -> {error E} -> {typeOf E T2}.\n intros Hyp1 Error. case Error. " in 
	if language_grammarLookupByCategory lan "Error" = [] then proofWhenThereAreNoErrors ^ "\n\n" else proofWhenThereAreNoErrors ^ "case Hyp1. search. \n\n"

let applyAllSchemasToOneLanguages_to_file filenameLan = 	
	let schemas = List.map parseTheSchema (!repoOfSchemas) in 
    let mapOfRel = [("left", Num 0); ("right", Num 1); ("exp", Num 1); ("out", Num 2)] in
    let schemas = List.map (fun schema -> Substitution.substitution_schemaByMap schema mapOfRel) schemas in
	let lan = parseOneLanguage filenameLan in 
	let result = List.concat (List.map (compile lan) schemas) in (* concat, so result is a list of theorem&proof *)
	let nameOfLanguage = Filename.chop_extension filenameLan in 
	(* generate Abella proof .thm *)
	let thm_file = open_out ("./generated/" ^ nameOfLanguage ^ ".thm") in
	output_string thm_file ("Specification \"" ^ nameOfLanguage ^ "\". \n"); 
    output_string thm_file "Close typ. \nClose term.\n";
  if !debug_flag then output_string thm_file (debug_progressesDefinition)
  else
	  output_string thm_file (progressesDefinition); 
	(*output_string thm_file (errorTypesAllTheorem lan); *)
	List.map (output_string thm_file) (List.map abella_thrAndProof result); 
    close_out thm_file;
	(* generate language definition .mod *)
	let mod_file = open_out ("./generated/" ^ nameOfLanguage ^ ".mod") in
	output_string mod_file ("module " ^ nameOfLanguage ^ ".\n\n"); 
	output_string mod_file (language_prettyPrintRules lan); 
    close_out mod_file;
    (* generate a .lan for debugging *)
    let out_lan = open_out ("./generated/" ^ nameOfLanguage ^ ".lan") in
    output_string out_lan (Pretty_printer_lan.prettyPrintLan lan);
    close_out out_lan;
    print_endline ("Proofs generated in ./generated/" ^ nameOfLanguage ^ ".thm");;



let () = match Array.to_list Sys.argv with 
  | [oneArg] -> List.hd (List.map applyAllSchemasToOneLanguages_to_file languagesFromRepo);
  | oneArg :: twoArg :: restOfCommandLineArgs -> 
		let flag : string = Sys.argv.(1) in
    if flag = "--debug" then
      let _ = debug_flag := true in
      let _ = repoOfSchemas := list_minus_last restOfCommandLineArgs in	  
		  applyAllSchemasToOneLanguages_to_file (List.last restOfCommandLineArgs)
    else 
     print_endline ("arg was not recognised")
	| otherwise -> print_endline ("Command line error: Too many arguments");


