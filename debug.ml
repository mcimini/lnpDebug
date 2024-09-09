open Lexing
open Pretty_printer_mod
open Pretty_printer_thm
 
let list_minus_last l = List.rev (List.tl (List.rev l))

let file_to_list (filename : string) : string list =
  let in_channel = open_in filename in 
  let lines = List.rev (Str.split (Str.regexp "\n") (In_channel.input_all in_channel)) in 
  close_in in_channel; lines
  
let trim_only_theorem (s: string) : string = List.hd (String.split_on_char '<' s)
	

let remove_empty_strings s = List.filter (fun s -> not(s = "")) s

let rec remove_fail (lst : string list) : string list =
    if lst = [] then [] else match List.hd lst with
        | "Match failed" -> [] @ remove_fail (List.tl lst)
        | "Line does not match expected pattern.\n" -> [] @ remove_fail (List.tl lst)
        | "THEOREM\n" -> [] @ remove_fail (List.tl lst)
(*        | "" -> [] @ remove_fail (List.tl lst) *)
        | n -> [n] @ remove_fail (List.tl lst)


let rec remove_blank_messages (debug_msg_list : string list) : string list =
   if debug_msg_list = [] then [] else
     let blank_msg_pattern = Str.regexp "Line \\([a-zA-Z0-9()= ]+\\)" in  (* [0-9]+ *)  
     if Str.string_match blank_msg_pattern (List.hd debug_msg_list) 0 && String.equal (List.nth debug_msg_list 1) "\n" then [] @ remove_blank_messages (List.tl debug_msg_list)
     else if String.equal (List.hd debug_msg_list) "\n" then [] @ remove_blank_messages (List.tl debug_msg_list)
     else [List.hd debug_msg_list] @ remove_blank_messages (List.tl debug_msg_list)


let get_thm_line (line : string) : string =
   let pattern = Str.regexp "^.*\\<a name=\"\\([0-9]+\\)\".*" in
   if Str.string_match pattern line 0 then
      let line_number = Str.matched_group 1 line in line_number
   else "Match failed"


let extract_thmLN (block : string list) : string =
	if (remove_fail (List.map get_thm_line block)) = [] then raise(Failure("extract_thmLN")) else 
  List.hd (remove_fail (List.map get_thm_line block))


let parse_line (line : string) : string list =
  let only_line_number = Str.regexp "^.*\\. %\\([0-9]+\\),\\([0-9]+\\)" in
  let theorem_encountered = Str.regexp "^.*Theorem.*" in
  let pattern = Str.regexp "^.*\\. %\\([0-9]+\\),\\([0-9]+\\)-\\(.*\\)" in
  if Str.string_match pattern line 0 then
    let line_number = Str.matched_group 1 line in
    let char_num = Str.matched_group 2 line in
    let instrns = Str.matched_group 3 line in
    let instr_list = Str.split (Str.regexp "-") instrns in instr_list
  else ["Pattern match failed"]


let entry_contains_for (instr : string) : bool =
  if String.sub instr 0 3 = "FOR" then true else false;;


let keep_entries_with_for (instr_list : string list) : string list =
  List.filter entry_contains_for instr_list                                                                                                                                                                      

let parse_instr (instr : string) : (string * string * string * string * string * string) =
  let pattern = Str.regexp "^\\([A-Z]+\\):\\([0-9]+\\),\\([0-9]+\\):\\([a-zA-Z0-9()= ]*\\):\\([0-9]*\\):\\([a-zA-Z0-9()= ]+\\)" in
  if Str.string_match pattern instr 0 then
    let instr_type = Str.matched_group 1 instr in
    let condition_line = Str.matched_group 2 instr in
    let condition_line_char = Str.matched_group 3 instr in
    let condition = Str.matched_group 6 instr in
    let hypothesis = Str.matched_group 4 instr in
    let arg_position = Str.matched_group 5 instr in
    (instr_type, condition_line, condition_line_char, condition, hypothesis, arg_position)
  else
     ("Instruction did not match the expected pattern", "", "", "", "", "")


let get_hyp_line (instr : string) (line : string) : string =
   let instr_info = parse_instr instr in
   let (instr_type, condition_line, condition_line_char, condition, hypothesis, arg_position) = instr_info in
   let split_line = String.split_on_char ' ' line in
   let first_word = if split_line = [] then raise(Failure("get_hyp_line")) else List.hd split_line in
   if String.equal first_word hypothesis then line else "Match failed"


let extract_hypLN (lines : string list) (instr : string) : string =
  if (remove_fail (List.map (get_hyp_line instr) lines)) = [] then "hyp_line not found" else 
  List.hd (remove_fail (List.map (get_hyp_line instr) lines))


let get_msg_from_instr (instr : string) : string =
    let instr_info = parse_instr instr in
    let (instr_type, condition_line, condition_line_char, condition, hypothesis, arg_position) = instr_info in
    match instr_type with
    | "FOR" ->
      Printf.sprintf "The instruction passed a For at Line %s, character number is %s and is about the iteration for %s." condition_line condition_line_char condition
    | "IF" ->
      Printf.sprintf "The instruction passed an If at Line %s, character number is %s and the condition was %s." condition_line condition_line_char condition
    | _ -> "Unknown instruction"


let debug_message (line : string) : string =
  let only_line_number = Str.regexp "^.*\\. %\\([0-9]+\\),\\([0-9]+\\)" in
  let theorem_encountered = Str.regexp "^.*Theorem.*" in
  let pattern = Str.regexp "^.*\\. %\\([0-9]+\\),\\([0-9]+\\)-\\(.*\\)" in
  if (Str.string_match pattern line 0) then
    let line_number = Str.matched_group 1 line in
    let char_num = Str.matched_group 2 line in
    let instrns = Str.matched_group 3 line in 
    let instr_list = Str.split (Str.regexp "-") instrns in
    let parsed_instr = List.map get_msg_from_instr instr_list in
    let rest_msg = String.concat " " parsed_instr in
    Printf.sprintf "Line number: %s, Character: %s. %s" line_number char_num rest_msg
  else if Str.string_match only_line_number line 0
  then let line_number = Str.matched_group 1 line in 
           let char_num = Str.matched_group 2 line in
           Printf.sprintf "Line number is %s, and the character number is %s. " line_number char_num
  else if Str.string_match theorem_encountered line 0 || line = "" (* String.capitalize line = line *)
  then "THEOREM"
  else "Line does not match expected pattern."
   

let rec highlight_parenthesis (args : string list) : string list =
   if args = [] then []
   else let arg = List.hd args in (if String.starts_with ~prefix:"(" arg then ["-" ^ arg] @ highlight_parenthesis (List.tl args)
       else if String.ends_with ~suffix:")" arg then [arg ^ "-"] @ highlight_parenthesis (List.tl args) 
       else [arg] @ highlight_parenthesis (List.tl args))


let rec final_args_list (args : string list) : string list =
        if args = [] then [] 
        else let arg = List.hd args in (if String.starts_with ~prefix:"(" arg then [arg] @ final_args_list (List.tl args)
             else String.split_on_char ' ' arg @ final_args_list (List.tl args))


let rec is_substring (str1 : string) (str2 : string) : bool =
  let len1 = String.length str1 in
  let len2 = String.length str2 in
  if len2 < len1 then false
  else (if String.equal (String.sub str2 0 len1) str1 then true
  else is_substring str1 (String.sub str2 1 (len2 - 1)));;


let rm_parentheses (str : string) : string =
   let len = String.length str in
   if String.starts_with ~prefix:"(" str && String.ends_with ~suffix:")" str then String.sub str 1 (len - 2) else str 


let rec get_blocks_indices (lines: string list) (line_num : int): int list =
  if lines = [] then [] else
  let first_line = List.hd lines in
  if is_substring  "<a" first_line then [line_num] @ get_blocks_indices (List.tl lines) (line_num + 1)
  else  get_blocks_indices (List.tl lines) (line_num + 1)


let rec split_into_blocks (lines : string list) (indices : int list) : (string list) list =
    let ln_to_line (i : int) : string =
      let start_pos = i + (List.hd indices) in
      List.nth lines start_pos in
    if List.length indices = 0 then []
    else if List.length indices = 1 then [List.init ((List.length lines) - List.hd indices) ln_to_line] @ split_into_blocks lines (List.tl indices)
    else [List.init ((List.nth indices 1) - List.hd indices) ln_to_line] @ split_into_blocks lines (List.tl indices)
	
let iteration_element_equality (iter : string) (arg : string) : bool =
	 if is_substring "abs" iter && is_substring "abs" arg then true else (* we need to replace this line with a better check *)
	 let iter = if String.starts_with "(" iter then iter else "(" ^ iter ^ ")" in 
	 let arg = if String.starts_with "(" arg then arg else "(" ^ arg ^ ")" in 
	 let term1 = try ParserLan.termString LexerLan.token (Lexing.from_string iter) with ParserLan.Error -> raise(Failure("Cannot parse: " ^ iter)) in 
	 let term2 = try ParserLan.termString LexerLan.token (Lexing.from_string arg) with ParserLan.Error -> raise(Failure("Cannot parse: " ^ arg)) in 
		 term1 = term2  
  (*   if (String.equal (rm_parentheses arg) (String.trim (rm_parentheses iter)))
      then true
     else false
*)
	  
    
let debug_one_block (thm_filename : string) (abella_filename : string) (block : string list) (forFound : bool) : (string * bool) =
  if forFound then "", true else 
  let thm_line = int_of_string (extract_thmLN block) in
  let thm_line_last = int_of_string (extract_thmLN (file_to_list abella_filename)) in
  let lines_in_reverse = file_to_list thm_filename in
  let lines = List.rev lines_in_reverse in
  let thm_line_we_seek = if List.length lines < thm_line then List.nth lines (thm_line - 2) else List.nth lines (thm_line - 1) in
  let thm_line_theorem_encountered = if thm_line > 1 then List.nth lines (thm_line - 2) else thm_line_we_seek in
  let last_line = List.nth (file_to_list abella_filename) 0 in
  let entry_list_only_For = keep_entries_with_for (parse_line thm_line_we_seek) in
(*  let entry_list_only_For_theorem_encountered = keep_entries_with_for (parse_line thm_line_theorem_encountered) in *)
  let instr_prev_line = if (parse_line thm_line_theorem_encountered) = [] then raise(Failure("debug_one_block")) else  List.hd (parse_line thm_line_theorem_encountered) in 
  let instr_info_prev_line = parse_instr instr_prev_line in
  let (instr_type_prev, condition_line_prev, condition_line_char_prev, condition_prev, hypothesis_prev, arg_position_prev) = instr_info_prev_line in   

   let rec check_in_synch (entry_list : string list) (forFound : bool) : (string * bool)  =
	 if forFound then "", true else 
  	 if entry_list = [] then "",forFound else (* || (!forFound)  *)
  	 let first_entry = List.hd entry_list in
  	 let entry_info = parse_instr first_entry in
  	 let (operator, line_number, line_char, iteration_element, hypothesis, arg_position) = entry_info in
	 if hypothesis = "" then "",forFound else
         (*let what_is_first_entry = raise(Failure(first_entry)) in*) 
  	 let hyp_line = extract_hypLN block first_entry in
         if String.equal hyp_line "hyp_line not found" then
                  check_in_synch (List.tl entry_list) forFound
         else
  	 let hyp_line_pattern = Str.regexp "^\\([A-Za-z0-9]+\\) : {\\([A-Za-z0-9()= ]+\\)}" in
  	 let hyp_formula = if Str.string_match hyp_line_pattern hyp_line 0 then Str.matched_group 2 hyp_line else "No pattern match" in
  	 let arg_list = Str.split (Str.regexp " ") hyp_formula in 
  	 let args_final_list = remove_fail (final_args_list (String.split_on_char '-' (String.concat " " (highlight_parenthesis arg_list)))) in
  	 (*"-----" ^ List.nth args_final_list (int_of_string arg_position) ^ "-----" ^ String.trim iteration_element*)
  	 if arg_position = "" then "",forFound else 
  	  if iteration_element_equality (iteration_element)  (List.nth (remove_empty_strings args_final_list) (int_of_string arg_position)) 
  	   then  check_in_synch (List.tl entry_list) forFound
  	   else "The for-loop at Line " ^ line_number ^ ", character number " ^ line_char ^ " is not in synch with Abella. \nThe case analysis was " ^ hyp_line ^ ".\nBut the element of the iteration was " ^ iteration_element ^ ".\n", true
		   
	   (* Modification: Now it reports only the first for-loop OF THE ENTRY that is not in synch
		   removed: ^ check_in_synch (List.tl entry_list)  *)
   in 

    if (String.equal (debug_message thm_line_we_seek) "THEOREM" && (thm_line = thm_line_last)) || List.length lines < thm_line 
(*	    if String.equal (debug_message thm_line_we_seek) "THEOREM" && (thm_line = thm_line_last || List.length lines < thm_line_last) *)
    then "The .lnp did not generate the proof instructions for completing the proof of theorem " ^ trim_only_theorem last_line ^ "\n" ^ "And the details of the last instruction for this proof are the following:\n" ^ debug_message thm_line_theorem_encountered,forFound
    else
		let (forMsg, forFound) = (check_in_synch entry_list_only_For forFound) in 
		(if String.equal forMsg "" && not (thm_line = thm_line_last) then ""
       else forMsg ^ "The details of the instruction that failed in the .lnp proof are the following:\n" ^ debug_message thm_line_we_seek ^ "\n"
	   ^ (if (trim_only_theorem last_line) = "Abella " || (trim_only_theorem last_line) = "" then "" else "The theorem name was " ^ (trim_only_theorem last_line))), forFound


let debug_complete (block : string list) : string =
        let second_to_last_line = List.nth block (List.length (block) - 2) in
        let completed_thm_name =  List.nth block (List.length (block) - 3) in
        if String.equal second_to_last_line "Proof completed." then
            let thm_complete_pattern = Str.regexp "^\\([a-zA-Z-]+\\)\\(.*\\)" in
            if Str.string_match thm_complete_pattern completed_thm_name 0 then
                 let trim_thm_name = Str.matched_group 1 completed_thm_name in
                "The proof of theorem " ^ trim_thm_name ^ " is completed but the .lnp has generated too many instructions for it."
            else "Match failed"
        else ""
       
        (*In debug function, if empty string, print clean message. Otherwise, print case 3 theorem complete message with the theorem name *)

let correct_proof (block : string list) : string =
        let second_to_last_line = List.nth block (List.length (block) - 2) in
        if String.equal second_to_last_line "Abella < Goodbye." then (* let _ = raise(Failure("detected abella goodbye")) in *)
                "This generated .thm is valid, all proofs are completed."
        else ""


let debug (thm_filename : string) (abella_filename : string) : string =
  let in_channel = open_in thm_filename in
  let output_lines = file_to_list abella_filename in
  let output_lines_rev = List.rev output_lines in
  let block_indices = get_blocks_indices output_lines_rev 0 in
  let block_list = split_into_blocks output_lines_rev block_indices in
  let last_block = List.nth block_list (List.length (block_list) - 1) in
  let proof_is_correct = correct_proof last_block in
  let rec debug_all_blocks (block_list : (string list) list) (i : int) (forFound : bool) : string list =
     if block_list = [] then []
	 else 
		 let (msgBlock, forFound) = debug_one_block thm_filename abella_filename (List.hd block_list) forFound in 
		 ["Line " ^ string_of_int i ^ " of the .thm Abella proof"] @ [msgBlock ^ "\n"] @ debug_all_blocks (List.tl block_list) (i + 1) forFound
  in
  let clean_message = if String.equal proof_is_correct "" then remove_blank_messages(remove_fail(debug_all_blocks block_list 1 false)) else remove_blank_messages(remove_fail(debug_all_blocks (list_minus_last block_list) 1 false)) in 
  let second_to_last_block = List.nth block_list (List.length (block_list) - 2) in
  let debug_complete_msg = if String.equal proof_is_correct "" then debug_complete second_to_last_block else "" in 
  proof_is_correct ^ "\n" ^ debug_complete_msg  ^ "\n" ^ String.concat "\n" clean_message 
  
   (*let what_is_block = raise(Failure(List.nth (List.hd block_list) 2)) in*)
  (*New function named no_errors or correct_proof - if final block second last line is "Abella goodbye" then error message is "Nothing ot debug" otherwise empty string. If empty string, continue and check the second to last block to see if proof completed*)
  (*Do check on second to last block. If proof completed, will print an error message. Otherwise, give clean message*)

let () = match Array.to_list Sys.argv with
     | [oneArg ; twoArg ] -> let thm_filename = Sys.argv.(1) in print_endline (debug thm_filename (thm_filename ^ ".output.txt"));
     
	 (*Lexing.(buf.lex_curr_p <- {buf.lex_curr_p with pos_cnum = 0}) ; P*)
