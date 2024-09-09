# Lang-n-Prove with Debugging System

This repo contains a copy of the <a href="https://github.com/mcimini/lang-n-prove">Lang-n-Prove tool</a> that has been augmented with a debugging system. 

Authors of Debugging System: 
<ul>
<li>Design: Charlesowityear Ly, Eswarasanthosh Kumar Mamillapalli, Matteo Cimini
<li>Implementation: Charlesowityear Ly, Eswarasanthosh Kumar Mamillapalli
<br />
with small contributions by Matteo Cimini. 
</ul>

Original Lang-n-Prove tool: 

<ul>
	Author: Matteo Cimini (matteo_cimini@uml.edu)
<br />
Subtyping support: Seth Galasso (seth.galasso@gmail.com)
</ul>
<br />

In this page, we give instructions on how to use the debugger and provide our tests. 
<br />
For instructions on how to use Lang-n-Prove, please refer to <a href="https://github.com/mcimini/lang-n-prove">the original repo of the tool</a>. 

# <a name="instructions"></a>Instructions 

Requirements: 
<br />
<ul>
<li> To compile and run: Ocaml with the Batteries and Menhir packages is required.
<li> To test the output of Lang-n-Prove: the <a href="http://abella-prover.org">Abella proof assistant</a> is required.  
</ul>

You can install these dependencies in thier own Opam switch with this command:
```
opam switch import dependencies.txt --switch lnp && eval $(opam env)
```

To build the the Lang-n-Prove tool and its debugger: 
<br />
<ul>
<li> make 
	<br/> this command builds the Lang-n-Prove tool (executable: ./lnp)
<li> make debug
	<br/> this command builds the debugger (executable: ./lnpDebug)
</ul>
<br />
Usage of the debugger: 
<br />
<ul>
<li> ./debug.sh file_1.lnp ... file_n.lnp langFile.lan
<br />
files <b>debug.sh</b> and <b>testOne.sh</b> of the main folder of the repo must have executable permissions. 
<br />
.lnp files are in the main folder of the repo. 
<br />
.lan files that are used for testing the debugger are in the folder "repo-Debug". 
<br />
</ul>
What it does:  <br />
<ul>
<li> executes Lang-n-Prove (with command ./lnp --debug) passing the above .lnp files and language file langFile.lan as input. 
<li> which generates an Abella proof file (.thm). 
<li> executes Abella in "annotated mode" on the generated .thm file and saves the output. 
<li> executes the debugger (with command ./lnpDebug) passing the generated .thm file and the saved Abella output. 
<li> and outputs a debugging message. 
</ul>


# <a name="tests"></a>Tests

The debugging system and our tests are described <a href="docs/lnpDebugger_paper.pdf">in this paper</a>.  
Please refer to the paper for their description, below we show how to apply the debugger to those examples and the output of the debugger.  

<ul>
<li> Example in Section 3.2 

``` 
./debug.sh canonical1.lnp iff.lan
```
output: <br /> 
Line 10 of the .thm Abella proof     
The details of the instruction that failed in the .lnp proof are the following:     
Line number: 7, Character: 4. The instruction passed a For at Line 6, character number is 0 and is about the iteration for (if E1 E2 E3).    
The theorem name was Canonical-form-bool 
<br />

<li> First Example in Section 3.3 
<br /> 
canonical2.lnp fixes the problem for iff.lan 

``` 
./debug.sh canonical2.lnp iff.lan
```
output: <br /> 
This generated .thm is valid, all proofs are completed.<br />


<li> Second Example in Section 3.3 
<br /> 
But canonical2.lnp does not work for stlc_iff.lan

``` 
./debug.sh canonical2.lnp stlc_iff.lan
```
output: <br /> 
Line 11 of the .thm Abella proof    
The for-loop at Line 6, character number 0 is not in synch with Abella.     
The case analysis was Main : {typeOf empty (app E1 E2) bool}.    
But the element of the iteration was (abs T1 (x)E2).    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 8, Character: 14. The instruction passed a For at Line 6, character number is 0 and is about the iteration for (abs T1 (x)E2). The instruction passed an If at Line 7, character number is 4 and the condition was (abs T1 (x)E2) is Value.    
The theorem name was Canonical-form-bool 
<br />


<li> Example in Section 3.4 

``` 
./debug.sh canonical2.lnp stlc_iff_inverted.lan
```
output: <br /> 
The proof of theorem Canonical-form-bool is completed but the .lnp has generated too many instructions for it.    
Line 12 of the .thm Abella proof    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 8, Character: 14. The instruction passed a For at Line 6, character number is 0 and is about the iteration for (abs T1 (x)E2). The instruction passed an If at Line 7, character number is 4 and the condition was (abs T1 (x)E2) is Value.    
<br />


<li>First Example in Section 3.5 
<br /> 
canonical3.lnp fixes the problem for stlc_iff.lan 

``` 
./debug.sh canonical3.lnp stlc_iff.lan
```
output: <br /> 
This generated .thm is valid, all proofs are completed.<br />


<li>Second Example in Section 3.5 
<br /> 
canonical3.lnp fixes the problem for stlc_iff_inverted.lan 

``` 
./debug.sh canonical3.lnp stlc_iff_inverted.lan
```
output: <br /> 
This generated .thm is valid, all proofs are completed.<br />



<li>Third Example in Section 3.5 

``` 
./debug.sh canonical3.lnp stlc_iff_sub.lan
```
output: <br /> 
Line 12 of the .thm Abella proof    
The .lnp did not generate the proof instructions for completing the proof of theorem Canonical-form-bool     
And the details of the last instruction for this proof are the following:    
Line number: 11, Character: 10. The instruction passed a For at Line 7, character number is 0 and is about the iteration for (app E1 E2). The instruction passed an If at Line 8, character number is 2 and the condition was (bool ) = ofType((app E1 E2)) or IsVar(ofType((app E1 E2))). The instruction passed an If at Line 9, character number is 6 and the condition was NOT((app E1 E2) is Value).    
<br />


<li>Example in Section 4: Another Incorrect Treatment of Non-values in Canonical Form Lemmas 

``` 
./debug.sh canonical4.lnp stlc_iff.lan
```
output: <br /> 
Line 10 of the .thm Abella proof    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 10, Character: 19. The instruction passed a For at Line 6, character number is 0 and is about the iteration for (if E1 E2 E3). The instruction passed an If at Line 7, character number is 4 and the condition was (bool ) = ofType((if E1 E2 E3)) or IsVar(ofType((if E1 E2 E3))). The instruction passed an If at Line 8, character number is 14 and the condition was NOT((if E1 E2 E3) is Value).    
The theorem name was Canonical-form-bool     
<br />


<li>Example in Section 4: Canonical Form Lemmas, Still Wrong 

``` 
./debug.sh canonical3.lnp stlc_iff_pairs.lan
```
output: <br /> 
Line 9 of the .thm Abella proof    
The for-loop at Line 7, character number 0 is not in synch with Abella.     
The case analysis was Main : {typeOf empty (pair E1 E2) (times T1 T2)}.    
But the element of the iteration was (app E1 E2).    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 11, Character: 10. The instruction passed a For at Line 7, character number is 0 and is about the iteration for (app E1 E2). The instruction passed an If at Line 8, character number is 2 and the condition was (times T1 T2) = ofType((app E1 E2)) or IsVar(ofType((app E1 E2))). The instruction passed an If at Line 9, character number is 6 and the condition was NOT((app E1 E2) is Value).    
The theorem name was Canonical-form-times     
<br />


<li>Example in Section 4: Incorrect Treatment of Elimination Forms in Progress 

```
./debug.sh progress-op1.lnp stlc_iff.lan
```
output: <br /> 
Line 14 of the .thm Abella proof    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 6, Character: 6. The instruction passed an If at Line 5, character number is 0 and the condition was isEliminationForm((if E1 E2 E3)).    
The theorem name was Progress-if     
<br />


<li>Example in Section 4: An Incomplete Proof for Progress When Subtyping is Present 

``` 
./debug.sh inversion-subtype.lnp canonical-sub.lnp progress-op-sub.lnp progress.lnp stlc_iff_sub.lan
```
output (takes longer to compute): <br /> 
Line 97 of the .thm Abella proof    
The .lnp did not generate the proof instructions for completing the proof of theorem Progress-thm     
And the details of the last instruction for this proof are the following:    
Line number: 7, Character: 1. The instruction passed a For at Line 5, character number is 0 and is about the iteration for (app E1 E2).    
<br />


<li>Example in Section 4: Incorrect Loop for the Main Progress Theorem 

``` 
./debug.sh canonical.lnp progress-op.lnp progress1.lnp stlc_iff.lan
```
output: <br /> 
Line 54 of the .thm Abella proof    
The for-loop at Line 5, character number 0 is not in synch with Abella.     
The case analysis was Main : {typeOf empty (if E1 E2 E3) typ}@.    
But the element of the iteration was (abs T R).    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 6, Character: 1. The instruction passed a For at Line 5, character number is 0 and is about the iteration for (abs T R).    
The theorem name was Progress-thm     
<br />


<li>Example in Section 4: Correct Abella Proof but Incorrect LNP Proof 

``` 
./debug.sh progress2.lnp unit.lan
```
output: <br /> 
This generated .thm is valid, all proofs are completed.    
<br />
Line 9 of the .thm Abella proof    
The for-loop at Line 5, character number 0 is not in synch with Abella.     
The case analysis was Main : {typeOf empty unit unitType}@.    
But the element of the iteration was (unitType ).    
The details of the instruction that failed in the .lnp proof are the following:    
Line number: 6, Character: 1. The instruction passed a For at Line 5, character number is 0 and is about the iteration for (unitType ).    
<br />


<li>Example in Section 4: Too Many Instructions When Subtyping Is Not Present 

``` 
./debug.sh canonical.lnp progress-op.lnp progress-sub.lnp stlc_iff.lan
```
output: <br /> 
The proof of theorem Progress-thm is completed but the .lnp has generated too many instructions for it.    
Line 60 of the .thm Abella proof    
The details of the instruction that failed in the .lnp proof are the following:    
Line number is 9, and the character number is 0.     
<br />
</ul>

