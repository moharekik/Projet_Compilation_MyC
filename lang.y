%{

#include "Table_des_symboles.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern int yylex();
extern int yyparse();

void yyerror (char* s) {
  printf ("%s\n",s);
  exit(0);
  }
		
 int depth=0; // block depth
 
 char* concatenate_strings(char* str1, char* str2) {
  char* result = (char*)malloc(strlen(str1) + strlen(str2) + 1);
  strcpy(result, str1);
  strcat(result, str2);
  return result;
}

int make_label(){
  static int n = 0;
  return n++;
}

int make_label_while(){
   static int n = 0;
  return n++;
}
%}

%union { 
  struct ATTRIBUTE * symbol_value;
  char * string_value;
  int int_value;
  float float_value;
  int type_value;
  int label_value;
  int offset_value;
}

%token <int_value> NUM
%token <float_value> DEC


%token INT FLOAT VOID

%token <string_value> ID
%token AO AF PO PF PV VIR
%token RETURN  EQ
%token <label_value> IF ELSE WHILE

%token <label_value> AND OR NOT DIFF EQUAL SUP INF
%token PLUS MOINS STAR DIV
%token DOT ARR

%nonassoc IFX
%left OR                       // higher priority on ||
%left AND                      // higher priority on &&
%left DIFF EQUAL SUP INF       // higher priority on comparison
%left PLUS MOINS               // higher priority on + - 
%left STAR DIV                 // higher priority on * /
%left DOT ARR                  // higher priority on . and -> 
%nonassoc UNA                  // highest priority on unary operator
%nonassoc ELSE


%{
char * type2string (int c) {
  switch (c)
    {
    case INT:
      return("int");
    case FLOAT:
      return("float");
    case VOID:
      return("void");
    default:
      return("type error");
    }  
};
//cette fonction sert à afficher une expression, elle prend en parametre les valeurs de $1 et $3 et l operateur 
int print_expression( int dollar_1, int dollar_3 ,char * operator){
                      int result ;
                              if (dollar_1 == INT) {
                                  if (dollar_3 == INT) {
                                      result = INT;
                                  }
                                  else if (dollar_3 == FLOAT) {
                                      printf("I2F2\n");
                                      result = FLOAT;
                                  }
                              }
                              else if (dollar_1 == FLOAT) {
                                  if (dollar_3 == INT) {
                                      printf("I2F\n");
                                      result = FLOAT;
                                  }
                                  else if (dollar_3 == FLOAT) {
                                      result = FLOAT;
                                  }
                              }
                              if (result == INT) { printf("%sI\n", operator);}
                              else if (result == FLOAT) { printf("%sF\n", operator);}
                              return result;
};
 // cette fonction sert à afficher LOADP(stack[...bp] +1) ou  STOREP(stack[...bp] +1)
void print_loadp_or_storep(int _depth, int symbole_depth, int symbole_offset ,char store_or_load){
                                // printf("_depth = %d, sym_depth = %d, sym_offset = %d\n", _depth, 
                                // symbole_depth, symbole_offset);
                                  switch(store_or_load){
                                      case 'l':
                                        printf("LOADP(");
                                        break;
                                      case 's':
                                        printf("STOREP(");
                                        break;
                                  }
                                  int i = _depth - symbole_depth;
                                  while (i > 0){
                                    printf("stack[");
                                    --i;
                                  }
                                  i = _depth - symbole_depth;
                                  printf("bp");
                                  while (i > 0){
                                    printf("]");
                                    --i;
                                  }
                                  printf(" + %d)\n", symbole_offset);
};
  %}


%start prog  

// liste de tous les non terminaux dont vous voulez manipuler l'attribut
%type <type_value> type exp  typename
%type <string_value> fun_head
 /* Attention, la rêgle de calcul par défaut $$=$1 
    peut créer des demandes/erreurs de type d'attribut */
%type <offset_value> prog glob_decl_list decl_list decl var_decl vlist  params
%type <label_value> if  else while bool_cond
%type <int_value> arglist args
%%

 // O. Déclaration globale

prog : glob_decl_list              {$$ = $1 ;}

glob_decl_list : glob_decl_list fun { $$ = $1 ;}
| glob_decl_list decl PV       {$$ = $2; } // le compteur pour les variables globale s
|                              {$$ = -1;} // empty glob_decl_list shall be forbidden, but usefull for offset computation

// I. Functions

fun : type fun_head fun_body   { }
;

fun_head : ID PO PF            {
          // Pas de déclaration de fonction à l'intérieur de fonctions !
          if (depth>0) yyerror("Function must be declared at top level~!\n");
            printf("void pcode_%s()", $1);
          }

      | ID PO params PF              {
          // Pas de déclaration de fonction à l'intérieur de fonctions !
          if (depth>0) yyerror("Function must be declared at top level~!\n");
          // char * parameters = $<string_value>3;
          // printf("%s pcode_%s( %s )", type2string($<type_value>0), $1,parameters);
          // free(parameters);
            printf("void pcode_%s()", $1);
      }
;

params: type ID vir params     {
                   /*  $<string_value>$ = concatenate_strings(
                      concatenate_strings(
                        concatenate_strings(type2string($<type_value>1), " " ), concatenate_strings($2, ",")), 
                        $<string_value>4); */
                   printf("$$ = %d\n", $$);
                   set_symbol_value($2, makeSymbol( $<type_value>1 , $<int_value>$ - INT - 2 , depth + 1 ));
                   $$ = $4 - 1;

                                } // récursion droite pour numéroter les paramètres du dernier au premier
| type ID                      { 
                   /* $<string_value>$ = concatenate_strings(concatenate_strings(type2string($<type_value>1), " "), $2); */
                   // ici on depth + 1 dans la profondeur de l argument car on a lu que deux
                    // parentheses int fun_name(int x){} alors on a pas encore entré dans le bloc
                    // pour incrementer depth                   
                   set_symbol_value($2, makeSymbol( $<type_value>1 , -1 , depth + 1  ));
}


vir : VIR                      {}
;

fun_body : fao block faf       {}
;

fao : AO                       { printf("{\n"); depth++;}
;
faf : AF                       { printf("}\n"); depth--;}
;


// II. Block
block:
decl_list inst_list            { }
;

// III. Declarations

decl_list : decl_list decl PV   {$$ = $1 + $2;} 
|                               { $$ = 0;}
;

decl: var_decl                  {$$ = $1; }
;

var_decl : type vlist          { $$ = $2; }
;

vlist: vlist vir ID            { // récursion gauche pour traiter les variables déclararées de gauche à droite
                                    $$ = $1+ 1; 
                                      set_symbol_value($<string_value>3, makeSymbol( $<type_value>0 , $$ , depth));
                                      if($<type_value>0 == INT){
                                        //on peut ne pas afficher l offset 
                                        printf("LOADI(0)\n");
                                      }
                                     else if($<type_value>0 == FLOAT){
                                      printf("LOADF(0.0)\n");
                                      }
} 
| ID                           {                            
                                    /*on recupere la valeur precedente de l offset dans l attribut
                                    glob_decl_list avec $<int_value>-1*/
                                    $$ = $<int_value>-1 + 1;
                                      set_symbol_value($1, makeSymbol( $<type_value>0 , $$ , depth  ));
                                      if($<type_value>0 == INT){
                                        printf("LOADI(0)\n");
                                      }
                                      else if($<type_value>0 == FLOAT){
                                        printf("LOADF(0.0)\n");
                                      }
}                             
;

type
: typename                     {}
;

typename
: INT                          {$$=INT;}
| FLOAT                        {$$=FLOAT;}
| VOID                         {$$=VOID;}
;

// IV. Intructions

inst_list: inst_list inst   {} 
| inst                      {}
;

pv : PV                       {}
;
 
inst:
ao block af                   {}
| aff pv                      {}
| ret pv                      {}
| cond                        {}
| loop                        {}
| pv                          {}
;

// Accolades explicites pour gerer l'entrée et la sortie d'un sous-bloc

ao : AO                       {printf("SAVEBP\n"); depth++;}
;

af : AF                       {printf("RESTOREBP\n");depth--;}
;


// IV.1 Affectations

aff : ID EQ exp               { 
      print_loadp_or_storep(depth, get_symbol_value($1)->depth , get_symbol_value($1)->offset, 's');
      }
;


// IV.2 Return
ret : RETURN exp              { printf("return;\n");}
| RETURN PO PF                {printf("return();\n");}
;

// IV.3. Conditionelles
//           N.B. ces rêgles génèrent un conflit déclage reduction
//           qui est résolu comme on le souhaite par un décalage (shift)
//           avec ELSE en entrée (voir y.output)

cond :
if bool_cond inst  elsop       {}
;

elsop : else inst              { printf("End_%d\n", $<label_value>-2); }
|                  %prec IFX   {} // juste un "truc" pour éviter le message de conflit shift / reduce
;

bool_cond : PO exp PF         {  
                              printf("GTF\n");
                              printf("IFN(False_%d)\n", $<label_value>0); //   regler
                              }
;

if : IF                       { $$ = make_label();}
;                                      


else : ELSE                   {
                              printf("GOTO(End_%d)\n", $<label_value>-2);
                              printf("False_%d:\n", $<label_value>-2); 
                              }
;
// faire memes modifs que le if 
// IV.4. Iterations

loop : while while_cond inst  {printf("GOTO(StartLoop_%d)\n", $<label_value>1);
                              printf("EndLoop_%d:\n", $<label_value>1);}
;

while_cond : PO exp PF        {
                              printf("GTI\n");
                              printf("IFN(EndLoop_%d)\n", $<label_value>0);
                                }

while : WHILE                 {$$ = make_label_while();
                              printf("StartLoop_%d:\n",  $$);}
;


// V. Expressions

// V.1 Exp. arithmetiques
exp
: MOINS exp %prec UNA         {}
         // -x + y lue comme (- x) + y  et pas - (x + y)
| exp PLUS exp                { 
                              // ajouter une message de errur en cas d erreur
                              $$ = print_expression($1, $3, "ADD");
                              }
| exp MOINS exp               {
                              $$ = print_expression($1, $3, "SUB");
                              }
| exp STAR exp                {
                              $$ = print_expression($1, $3, "MULT");
                                }               
| exp DIV exp                 { 
                              $$ = print_expression($1, $3, "DIV");
                              }
| PO exp PF                   {/*$$ = $2;*/}
| ID                          { 
                                $$ = get_symbol_value($1)->type;
                                // on garde l ancien affichage pour les varoables globales 
                                if(depth == 0){
                                  printf("LOADP(%d)\n", get_symbol_value($1)->offset);
                                }
                                else{
                                 print_loadp_or_storep(depth, get_symbol_value($1)->depth , get_symbol_value($1)->offset, 'l');
                                }
  }
| app                         {}
| NUM                         {$$ = INT ; printf("LOADI(%d)\n", $1 );}
| DEC                         {$$ = FLOAT; printf("LOADF(%f)\n", $1 );}


// V.2. Booléens

| NOT exp %prec UNA           {}
| exp INF exp                 {}
| exp SUP exp                 {}
| exp EQUAL exp               {}
| exp DIFF exp                {}
| exp AND exp                 {}
| exp OR exp                  {}

;

// V.3 Applications de fonctions


app : fid PO args PF          {
                              printf("SAVEBP\n"); 
                              printf("CALL(pcode_%s)\n", $<string_value>1);
                              printf("RESTOREBP\n");
                              printf("ENDCALL(%d)\n", $3);
                              
                              }
;

fid : ID                      { $<string_value>$ = $1; }

args :  arglist               { $$ = $1; // on remonte la valeur du nombre d arguments 
                                }
|                             {$$ = 0;}
;

arglist : arglist VIR exp     { // on stocke le nombre d arguments ici
                                $$ = $1 + 1;} // récursion gauche pour empiler les arguements de la fonction de gauche à droite
| exp                         { $$ = 1;}
;



%% 
int main () {

  /* Ici on peut ouvrir le fichier source, avec les messages 
     d'erreur usuel si besoin, et rediriger l'entrée standard 
     sur ce fichier pour lancer dessus la compilation.
   */

char * header=
"// PCode Header\n\
#include \"PCode.h\"\n\
\n\
int main() {\n\
pcode_main();\n\
return stack[sp-1].int_value;\n\
}\n";  

 printf("%s\n",header); // ouput header
  
return yyparse ();
 
 
} 

