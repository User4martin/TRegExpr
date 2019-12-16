unit RegExpr;

{
  TRegExpr class library
  Delphi Regular Expressions

  Copyright (c) 1999-2004 Andrey V. Sorokin, St.Petersburg, Russia

  You can choose to use this Pascal unit in one of the two following licenses:

  Option 1>

  You may use this software in any kind of development,
  including comercial, redistribute, and modify it freely,
  under the following restrictions :
  1. This software is provided as it is, without any kind of
  warranty given. Use it at Your own risk.The author is not
  responsible for any consequences of use of this software.
  2. The origin of this software may not be mispresented, You
  must not claim that You wrote the original software. If
  You use this software in any kind of product, it would be
  appreciated that there in a information box, or in the
  documentation would be an acknowledgement like

  Partial Copyright (c) 2004 Andrey V. Sorokin
  http://RegExpStudio.com
  mailto:anso@mail.ru

  3. You may not have any income from distributing this source
  (or altered version of it) to other developers. When You
  use this product in a comercial package, the source may
  not be charged seperatly.
  4. Altered versions must be plainly marked as such, and must
  not be misrepresented as being the original software.
  5. RegExp Studio application and all the visual components as
  well as documentation is not part of the TRegExpr library
  and is not free for usage.

  mailto:anso@mail.ru
  http://RegExpStudio.com
  http://anso.da.ru/

  Option 2>

  The same modified LGPL with static linking exception as the Free Pascal RTL
}

interface

{ off $DEFINE DebugSynRegExpr }
// ======== Determine compiler
{$I regexpr_compilers.inc}
// ======== Define base compiler options
{$BOOLEVAL OFF}
{$EXTENDEDSYNTAX ON}
{$LONGSTRINGS ON}
{$OPTIMIZATION ON}
{$IFDEF D6}
  {$WARN SYMBOL_PLATFORM OFF} // Suppress .Net warnings
{$ENDIF}
{$IFDEF D7}
  {$WARN UNSAFE_CAST OFF} // Suppress .Net warnings
  {$WARN UNSAFE_TYPE OFF} // Suppress .Net warnings
  {$WARN UNSAFE_CODE OFF} // Suppress .Net warnings
{$ENDIF}
{$IFDEF FPC}
  {$MODE DELPHI} // Delphi-compatible mode in FreePascal
  {$INLINE ON}
{$ENDIF}
// ======== Define options for TRegExpr engine
{ off $DEFINE UniCode} // Use WideChar for characters and UnicodeString/WideString for strings
{ off $DEFINE UseWordChars} // Use WordChars property, otherwise fixed list 'a'..'z','A'..'Z','0'..'9','_'
{ off $DEFINE UseSpaceChars} // Use SpaceChars property, otherwise fixed list
{ off $DEFINE UnicodeWordDetection} // Additionally to ASCII word chars, detect word chars >=128 by Unicode table
{$DEFINE RegExpPCodeDump} // p-code dumping (see Dump method)
{$IFNDEF FPC} // the option is not supported in FreePascal
  {$DEFINE reRealExceptionAddr} // exceptions will point to appropriate source line, not to Error procedure
{$ENDIF}
{$DEFINE ComplexBraces} // support braces in complex cases
{$IFNDEF UniCode} // the option applicable only for non-UniCode mode
  {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}  // sets have to be aligned
    {$DEFINE UseSetOfChar} // Significant optimization by using set of char
  {$ENDIF}
{$ENDIF}
{$IFDEF UseSetOfChar}
  {$DEFINE UseFirstCharSet} // Fast skip between matches for r.e. that starts with determined set of chars
{$ENDIF}
{$IFNDEF UniCode}
  {$UNDEF UnicodeWordDetection}
{$ENDIF}
{$IFNDEF UseWordChars}
  {$UNDEF UseSetOfChar}
  {$UNDEF UseFirstCharSet}
{$ENDIF}
// ======== Define Pascal-language options
// Define 'UseAsserts' option (do not edit this definitions).
// Asserts used to catch 'strange bugs' in TRegExpr implementation (when something goes
// completely wrong). You can swith asserts on/off with help of {$C+}/{$C-} compiler options.
{$IFDEF D3} {$DEFINE UseAsserts} {$ENDIF}
{$IFDEF FPC} {$DEFINE UseAsserts} {$ENDIF}
// Define 'use subroutine parameters default values' option (do not edit this definition).
{$IFDEF D4} {$DEFINE DefParam} {$ENDIF}
{$IFDEF FPC} {$DEFINE DefParam} {$ENDIF}
// Define 'OverMeth' options, to use method overloading (do not edit this definitions).
{$IFDEF D5} {$DEFINE OverMeth} {$ENDIF}
{$IFDEF FPC} {$DEFINE OverMeth} {$ENDIF}
// Define 'InlineFuncs' options, to use inline keyword (do not edit this definitions).
{$IFDEF D8} {$DEFINE InlineFuncs} {$ENDIF}
{$IFDEF FPC} {$DEFINE InlineFuncs} {$ENDIF}

uses
  Classes, // TStrings in Split method
  SysUtils; // Exception

type
  {$IFNDEF FPC}
  PtrInt = integer;
  PtrUInt = cardinal;
  {$ENDIF}
  {$IFDEF UniCode}
  PRegExprChar = PWideChar;
  {$IFDEF FPC}
  RegExprString = UnicodeString;
  {$ELSE}
    {$IFDEF D2009}
    RegExprString = UnicodeString;
    {$ELSE}
    RegExprString = WideString;
    {$ENDIF}
  {$ENDIF}
  REChar = WideChar;
  {$ELSE}
  PRegExprChar = PChar;
  RegExprString = AnsiString; // ###0.952 was string
  REChar = Char;
  {$ENDIF}
  TREOp = REChar; // internal p-code type //###0.933
  PREOp = ^TREOp;
  TRENextOff = PtrInt;
  // internal Next "pointer" (offset to current p-code) //###0.933
  PRENextOff = ^TRENextOff;
  // used for extracting Next "pointers" from compiled r.e. //###0.933
  TREBracesArg = integer; // type of {m,n} arguments
  PREBracesArg = ^TREBracesArg;

const
  REOpSz = SizeOf(TREOp) div SizeOf(REChar);
  // size of p-code in RegExprString units
  {$IFDEF FPC_REQUIRES_PROPER_ALIGNMENT}
  // add space for aligning pointer
  // -1 is the correct max size but also needed for InsertOperator that needs a multiple of pointer size
  RENextOffSz = (2 * SizeOf(TRENextOff) div SizeOf(REChar)) - 1;
  REBracesArgSz = (2 * SizeOf(TREBracesArg) div SizeOf(REChar));
  // add space for aligning pointer
  {$ELSE}
  RENextOffSz = (SizeOf(TRENextOff) div SizeOf(REChar));
  // size of Next 'pointer' -"-
  REBracesArgSz = SizeOf(TREBracesArg) div SizeOf(REChar);
  // size of BRACES arguments -"-
  {$ENDIF}

type
  TRegExprInvertCaseFunction = function(const Ch: REChar): REChar of object;

const
  EscChar = '\';
  // 'Escape'-char ('\' in common r.e.) used for escaping metachars (\w, \d etc).
  RegExprModifierI: boolean = False; // default value for ModifierI
  RegExprModifierR: boolean = True; // default value for ModifierR
  RegExprModifierS: boolean = True; // default value for ModifierS
  RegExprModifierG: boolean = True; // default value for ModifierG
  RegExprModifierM: boolean = False; // default value for ModifierM
  RegExprModifierX: boolean = False; // default value for ModifierX
  {$IFDEF UseSpaceChars}
  RegExprSpaceChars: RegExprString = // default value for SpaceChars
    ' '#$9#$A#$D#$C;
  {$ENDIF}
  {$IFDEF UseWordChars}
  RegExprWordChars: RegExprString = // default value for WordChars
    '0123456789' // ###0.940
    + 'abcdefghijklmnopqrstuvwxyz' + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_';
  {$ENDIF}
  RegExprLineSeparators: RegExprString = // default value for LineSeparators
    #$d#$a#$b#$c {$IFDEF UniCode} + #$2028#$2029#$85{$ENDIF};
  RegExprLinePairedSeparator: RegExprString =
  // default value for LinePairedSeparator
    #$d#$a;
  { if You need Unix-styled line separators (only \n), then use:
    RegExprLineSeparators = #$a;
    RegExprLinePairedSeparator = '';
  }
  // Tab and Unicode categoty "Space Separator": https://www.compart.com/en/unicode/category/Zs
  RegExprHorzSeparators: RegExprString = #9#$20#$A0
  {$IFDEF UniCode} +
    #$1680#$2000#$2001#$2002#$2003#$2004#$2005#$2006#$2007#$2008#$2009#$200A#$202F#$205F#$3000{$ENDIF};

const
  NSUBEXP = 90; // max number of subexpression //###0.929
  // Cannot be more than NSUBEXPMAX
  // Be carefull - don't use values which overflow CLOSE opcode
  // (in this case you'll get compiler error).
  // Big NSUBEXP will cause more slow work and more stack required
  NSUBEXPMAX = 255; // Max possible value for NSUBEXP. //###0.945
  // Don't change it! It's defined by internal TRegExpr design.

  MaxBracesArg = $7FFFFFFF - 1; // max value for {n,m} arguments //###0.933

  {$IFDEF ComplexBraces}
  LoopStackMax = 10; // max depth of loops stack //###0.925
  {$ENDIF}
  TinySetLen = 3;
  // if range includes more then TinySetLen chars, //###0.934
  // then use full (32 bytes) ANYOFFULL instead of ANYOF[BUT]TINYSET
  // !!! Attension ! If you change TinySetLen, you must
  // change code marked as "//!!!TinySet"

type

  {$IFDEF UseSetOfChar}
  PSetOfREChar = ^TSetOfREChar;
  TSetOfREChar = set of REChar;
  {$ENDIF}
  TRegExpr = class;

  TRegExprReplaceFunction = function(ARegExpr: TRegExpr)
    : RegExprString of object;

  { TRegExpr }

  TRegExpr = class
  private
    FUseOsLineEndOnReplace: boolean;
    startp: array [0 .. NSUBEXP - 1] of PRegExprChar;
    // founded expr starting points
    endp: array [0 .. NSUBEXP - 1] of PRegExprChar; // founded expr end points
    FSubExprIndexes: array [0 .. NSUBEXP - 1] of integer;
    FSubExprCount: integer;

    {$IFDEF ComplexBraces}
    LoopStack: array [1 .. LoopStackMax] of integer;
    // state before entering loop
    LoopStackIdx: integer; // 0 - out of all loops
    {$ENDIF}
    // The "internal use only" fields to pass info from compile
    // to execute that permits the execute phase to run lots faster on
    // simple cases.
    regstart: REChar; // char that must begin a match; '\0' if none obvious
    reganch: REChar; // is the match anchored (at beginning-of-line only)?
    regmust: PRegExprChar;
    // string (pointer into program) that match must include, or nil
    regmlen: PtrInt; // length of regmust string
    // Regstart and reganch permit very fast decisions on suitable starting points
    // for a match, cutting down the work a lot. Regmust permits fast rejection
    // of lines that cannot possibly match. The regmust tests are costly enough
    // that regcomp() supplies a regmust only if the r.e. contains something
    // potentially expensive (at present, the only such thing detected is * or +
    // at the start of the r.e., which can involve a lot of backup). Regmlen is
    // supplied because the test in regexec() needs it and regcomp() is computing
    // it anyway.
    {$IFDEF UseFirstCharSet} // ###0.929
    FirstCharSet: TSetOfREChar;
    {$ENDIF}
    // work variables for Exec's routins - save stack in recursion}
    reginput: PRegExprChar; // String-input pointer.
    fInputStart: PRegExprChar; // Pointer to first char of input string.
    fInputEnd: PRegExprChar; // Pointer to char AFTER last char of input string
    fRegexStart: PRegExprChar;
    fRegexEnd: PRegExprChar;
    fMetaStart: PRegExprChar;
    fMetaEnd: PRegExprChar;

    // work variables for compiler's routines
    regparse: PRegExprChar; // Input-scan pointer.
    regnpar: PtrInt; // count.
    regdummy: Char;
    regcode: PRegExprChar; // Code-emit pointer; @regdummy = don't.
    regsize: PtrInt; // Code size.

    regexpbeg: PRegExprChar; // only for error handling. Contains
    // pointer to beginning of r.e. while compiling
    fExprIsCompiled: boolean; // true if r.e. successfully compiled
    fSecondPass: boolean;

    // programm is essentially a linear encoding
    // of a nondeterministic finite-state machine (aka syntax charts or
    // "railroad normal form" in parsing technology). Each node is an opcode
    // plus a "next" pointer, possibly plus an operand. "Next" pointers of
    // all nodes except BRANCH implement concatenation; a "next" pointer with
    // a BRANCH on both ends of it connects two alternatives. (Here we
    // have one of the subtle syntax dependencies: an individual BRANCH (as
    // opposed to a collection of them) is never concatenated with anything
    // because of operator precedence.) The operand of some types of node is
    // a literal string; for others, it is a node leading into a sub-FSM. In
    // particular, the operand of a BRANCH node is the first node of the branch.
    // (NB this is *not* a tree structure: the tail of the branch connects
    // to the thing following the set of BRANCHes.) The opcodes are:
    programm: PRegExprChar; // Unwarranted chumminess with compiler.

    fExpression: RegExprString; // source of compiled r.e.
    fInputString: RegExprString; // input string

    fLastError: integer; // see Error, LastError

    fModifiers: integer; // modifiers
    fCompModifiers: integer; // compiler's copy of modifiers
    fProgModifiers: integer; // modifiers values from last programm compilation

    {$IFDEF UseSpaceChars}
    fSpaceChars: RegExprString; // ###0.927
    {$ENDIF}
    {$IFDEF UseWordChars}
    fWordChars: RegExprString; // ###0.929
    {$ENDIF}
    fInvertCase: TRegExprInvertCaseFunction; // ###0.927

    fLineSeparators: RegExprString; // ###0.941
    fLinePairedSeparatorAssigned: boolean;
    fLinePairedSeparatorHead, fLinePairedSeparatorTail: REChar;
    FReplaceLineEnd: String;
    {$IFNDEF UniCode}
    fLineSeparatorsSet: set of REChar;
    {$ENDIF}
    {$IFDEF UnicodeWordDetection}
    FUseUnicodeWordDetection: boolean;
    {$ENDIF}
    procedure ClearInternalIndexes;
    function IsWordChar(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline;{$ENDIF}
    function IsSpaceChar(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline;{$ENDIF}
    function IsDigitChar(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline;{$ENDIF}
    function IsHorzSeparator(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline; {$ENDIF}
    function IsLineSeparator(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline; {$ENDIF}
    // Mark programm as having to be [re]compiled
    procedure InvalidateProgramm;

    // Check if we can use precompiled r.e. or
    // [re]compile it if something changed
    function IsProgrammOk: boolean; // ###0.941

    procedure SetExpression(const s: RegExprString);

    function GetModifierStr: RegExprString;
    // Parse AModifiers string and return true and set AModifiersInt
    // if it's in format 'ismxrg-ismxrg'.
    class function ParseModifiersStr(const AModifiers: RegExprString;
      var AModifiersInt: integer): boolean; // ###0.941 class function now
    procedure SetModifierStr(const AModifiers: RegExprString);

    function GetModifier(AIndex: integer): boolean;
    procedure SetModifier(AIndex: integer; ASet: boolean);

    // Default handler raises exception ERegExpr with
    // Message = ErrorMsg (AErrorID), ErrorCode = AErrorID
    // and CompilerErrorPos = value of property CompilerErrorPos.
    procedure Error(AErrorID: integer); virtual; // error handler.

    { ==================== Compiler section =================== }
    // compile a regular expression into internal code
    function CompileRegExpr(exp: PRegExprChar): boolean;
    procedure SetUseOsLineEndOnReplace(AValue: boolean);

    // set the next-pointer at the end of a node chain
    procedure Tail(p: PRegExprChar; val: PRegExprChar);

    // regoptail - regtail on operand of first argument; nop if operandless
    procedure OpTail(p: PRegExprChar; val: PRegExprChar);

    // regnode - emit a node, return location
    function EmitNode(op: TREOp): PRegExprChar;

    // emit (if appropriate) a byte of code
    procedure EmitC(b: REChar);

    // insert an operator in front of already-emitted operand
    // Means relocating the operand.
    procedure InsertOperator(op: TREOp; opnd: PRegExprChar; sz: integer);
    // ###0.90

    // regular expression, i.e. main body or parenthesized thing
    function ParseReg(paren: integer; var flagp: integer): PRegExprChar;

    // one alternative of an | operator
    function ParseBranch(var flagp: integer): PRegExprChar;

    // something followed by possible [*+?]
    function ParsePiece(var flagp: integer): PRegExprChar;

    function HexDig(Ch: REChar): PtrInt;

    function UnQuoteChar(var APtr: PRegExprChar): REChar;

    // the lowest level
    function ParseAtom(var flagp: integer): PRegExprChar;

    // current pos in r.e. - for error hanling
    function GetCompilerErrorPos: PtrInt;

    {$IFDEF UseFirstCharSet} // ###0.929
    procedure FillFirstCharSet(prog: PRegExprChar);
    {$ENDIF}
    { ===================== Matching section =================== }
    // repeatedly match something simple, report how many
    function regrepeat(p: PRegExprChar; AMax: PtrInt): PtrInt;

    // dig the "next" pointer out of a node
    function regnext(p: PRegExprChar): PRegExprChar;

    // recursively matching routine
    function MatchPrim(prog: PRegExprChar): boolean;

    // Exec for stored InputString
    function ExecPrim(AOffset: PtrInt): boolean;

    {$IFDEF RegExpPCodeDump}
    function DumpOp(op: TREOp): RegExprString;
    {$ENDIF}
    function GetMatchPos(Idx: integer): PtrInt;
    function GetMatchLen(Idx: integer): PtrInt;
    function GetMatch(Idx: integer): RegExprString;

    procedure SetInputString(const AInputString: RegExprString);

    {$IFNDEF UseSetOfChar}
    function StrScanCI(s: PRegExprChar; Ch: REChar): PRegExprChar; // ###0.928
    {$ENDIF}
    procedure SetLineSeparators(const AStr: RegExprString);
    procedure SetLinePairedSeparator(const AStr: RegExprString);
    function GetLinePairedSeparator: RegExprString;

  public
    constructor Create; {$IFDEF OverMeth} overload;
    constructor Create(const AExpression: RegExprString); overload;
    {$ENDIF}
    destructor Destroy; override;

    class function VersionMajor: integer; // ###0.944
    class function VersionMinor: integer; // ###0.944

    // match a programm against a string AInputString
    // !!! Exec store AInputString into InputString property
    // For Delphi 5 and higher available overloaded versions - first without
    // parameter (uses already assigned to InputString property value)
    // and second that has PtrInt parameter and is same as ExecPos
    function Exec(const AInputString: RegExprString): boolean;
    {$IFDEF OverMeth} overload;
    function Exec: boolean; overload; // ###0.949
    function Exec(AOffset: PtrInt): boolean; overload; // ###0.949
    {$ENDIF}
    // find next match:
    // ExecNext;
    // works the same as
    // if MatchLen [0] = 0 then ExecPos (MatchPos [0] + 1)
    // else ExecPos (MatchPos [0] + MatchLen [0]);
    // but it's more simpler !
    // Raises exception if used without preceeding SUCCESSFUL call to
    // Exec* (Exec, ExecPos, ExecNext). So You always must use something like
    // if Exec (InputString) then repeat { proceed results} until not ExecNext;
    function ExecNext: boolean;

    // find match for InputString starting from AOffset position
    // (AOffset=1 - first char of InputString)
    function ExecPos(AOffset: PtrInt {$IFDEF DefParam} = 1{$ENDIF}): boolean;

    // Returns ATemplate with '$&' or '$0' replaced by whole r.e.
    // occurence and '$n' replaced by occurence of subexpression #n.
    // Since v.0.929 '$' used instead of '\' (for future extensions
    // and for more Perl-compatibility) and accept more then one digit.
    // If you want place into template raw '$' or '\', use prefix '\'
    // Example: '1\$ is $2\\rub\\' -> '1$ is <Match[2]>\rub\'
    // If you want to place raw digit after '$n' you must delimit
    // n with curly braces '{}'.
    // Example: 'a$12bc' -> 'a<Match[12]>bc'
    // 'a${1}2bc' -> 'a<Match[1]>2bc'.
    function Substitute(const ATemplate: RegExprString): RegExprString;

    // Split AInputStr into APieces by r.e. occurencies
    // Internally calls Exec[Next]
    procedure Split(const AInputStr: RegExprString; APieces: TStrings);

    function Replace(const AInputStr: RegExprString;
      const AReplaceStr: RegExprString;
      AUseSubstitution: boolean{$IFDEF DefParam} = False{$ENDIF}) // ###0.946
      : RegExprString; {$IFDEF OverMeth} overload;
    function Replace(const AInputStr: RegExprString;
      AReplaceFunc: TRegExprReplaceFunction): RegExprString; overload;
    {$ENDIF}
    // Returns AInputStr with r.e. occurencies replaced by AReplaceStr
    // If AUseSubstitution is true, then AReplaceStr will be used
    // as template for Substitution methods.
    // For example:
    // Expression := '({-i}block|var)\s*\(\s*([^ ]*)\s*\)\s*';
    // Replace ('BLOCK( test1)', 'def "$1" value "$2"', True);
    // will return:  def 'BLOCK' value 'test1'
    // Replace ('BLOCK( test1)', 'def "$1" value "$2"')
    // will return:  def "$1" value "$2"
    // Internally calls Exec[Next]
    // Overloaded version and ReplaceEx operate with call-back function,
    // so you can implement really complex functionality.
    function ReplaceEx(const AInputStr: RegExprString;
      AReplaceFunc: TRegExprReplaceFunction): RegExprString;

    // Returns ID of last error, 0 if no errors (unusable if
    // Error method raises exception) and clear internal status
    // into 0 (no errors).
    function LastError: integer;

    // Returns Error message for error with ID = AErrorID.
    function ErrorMsg(AErrorID: integer): RegExprString; virtual;

    // Converts Ch into upper case if it in lower case or in lower
    // if it in upper (uses current system local setings)
    class function InvertCaseFunction(const Ch: REChar): REChar;

    // [Re]compile r.e. Useful for example for GUI r.e. editors (to check
    // all properties validity).
    procedure Compile; // ###0.941

    {$IFDEF RegExpPCodeDump}
    // dump a compiled regexp in vaguely comprehensible form
    function Dump: RegExprString;
    {$ENDIF}
    // Regular expression.
    // For optimization, TRegExpr will automatically compiles it into 'P-code'
    // (You can see it with help of Dump method) and stores in internal
    // structures. Real [re]compilation occures only when it really needed -
    // while calling Exec[Next], Substitute, Dump, etc
    // and only if Expression or other P-code affected properties was changed
    // after last [re]compilation.
    // If any errors while [re]compilation occures, Error method is called
    // (by default Error raises exception - see below)
    property Expression: RegExprString read fExpression write SetExpression;

    // Set/get default values of r.e.syntax modifiers. Modifiers in
    // r.e. (?ismx-ismx) will replace this default values.
    // If you try to set unsupported modifier, Error will be called
    // (by defaul Error raises exception ERegExpr).
    property ModifierStr: RegExprString read GetModifierStr
      write SetModifierStr;

    // Modifier /i - caseinsensitive, initialized from RegExprModifierI
    property ModifierI: boolean index 1 read GetModifier write SetModifier;

    // Modifier /r - use r.e.syntax extended for russian,
    // (was property ExtSyntaxEnabled in previous versions)
    // If true, then а-я  additional include russian letter 'ё',
    // А-Я  additional include 'Ё', and а-Я include all russian symbols.
    // You have to turn it off if it can interfere with you national alphabet.
    // , initialized from RegExprModifierR
    property ModifierR: boolean index 2 read GetModifier write SetModifier;

    // Modifier /s - '.' works as any char (else as [^\n]),
    // , initialized from RegExprModifierS
    property ModifierS: boolean index 3 read GetModifier write SetModifier;

    // Switching off modifier /g switchs all operators in
    // non-greedy style, so if ModifierG = False, then
    // all '*' works as '*?', all '+' as '+?' and so on.
    // , initialized from RegExprModifierG
    property ModifierG: boolean index 4 read GetModifier write SetModifier;

    // Treat string as multiple lines. That is, change `^' and `$' from
    // matching at only the very start or end of the string to the start
    // or end of any line anywhere within the string.
    // , initialized from RegExprModifierM
    property ModifierM: boolean index 5 read GetModifier write SetModifier;

    // Modifier /x - eXtended syntax, allow r.e. text formatting,
    // see description in the help. Initialized from RegExprModifierX

    property ModifierX: boolean index 6 read GetModifier write SetModifier;
    // returns current input string (from last Exec call or last assign
    // to this property).
    // Any assignment to this property clear Match* properties !
    property InputString: RegExprString read fInputString write SetInputString;

    // Number of subexpressions has been found in last Exec* call.
    // If there are no subexpr. but whole expr was found (Exec* returned True),
    // then SubExprMatchCount=0, if no subexpressions nor whole
    // r.e. found (Exec* returned false) then SubExprMatchCount=-1.
    // Note, that some subexpr. may be not found and for such
    // subexpr. MathPos=MatchLen=-1 and Match=''.
    // For example: Expression := '(1)?2(3)?';
    // Exec ('123'): SubExprMatchCount=2, Match[0]='123', [1]='1', [2]='3'
    // Exec ('12'): SubExprMatchCount=1, Match[0]='12', [1]='1'
    // Exec ('23'): SubExprMatchCount=2, Match[0]='23', [1]='', [2]='3'
    // Exec ('2'): SubExprMatchCount=0, Match[0]='2'
    // Exec ('7') - return False: SubExprMatchCount=-1
    property SubExprMatchCount: integer read FSubExprCount;

    // pos of entrance subexpr. #Idx into tested in last Exec*
    // string. First subexpr. has Idx=1, last - MatchCount,
    // whole r.e. has Idx=0.
    // Returns -1 if in r.e. no such subexpr. or this subexpr.
    // not found in input string.
    property MatchPos[Idx: integer]: PtrInt read GetMatchPos;

    // len of entrance subexpr. #Idx r.e. into tested in last Exec*
    // string. First subexpr. has Idx=1, last - MatchCount,
    // whole r.e. has Idx=0.
    // Returns -1 if in r.e. no such subexpr. or this subexpr.
    // not found in input string.
    // Remember - MatchLen may be 0 (if r.e. match empty string) !
    property MatchLen[Idx: integer]: PtrInt read GetMatchLen;

    // == copy (InputString, MatchPos [Idx], MatchLen [Idx])
    // Returns '' if in r.e. no such subexpr. or this subexpr.
    // not found in input string.
    property Match[Idx: integer]: RegExprString read GetMatch;

    // Returns position in r.e. where compiler stopped.
    // Useful for error diagnostics
    property CompilerErrorPos: PtrInt read GetCompilerErrorPos;

    {$IFDEF UseSpaceChars}
    // Contains chars, treated as /s (initially filled with RegExprSpaceChars
    // global constant)
    property SpaceChars: RegExprString read fSpaceChars write fSpaceChars;
    // ###0.927
    {$ENDIF}

    {$IFDEF UseWordChars}
    // Contains chars, treated as /w (initially filled with RegExprWordChars
    // global constant)
    property WordChars: RegExprString read fWordChars write fWordChars;
    // ###0.929
    {$ENDIF}

    {$IFDEF UnicodeWordDetection}
    // If set to true, in addition to using WordChars, a heuristic to detect unicode word letters is used for \w
    property UseUnicodeWordDetection: boolean read FUseUnicodeWordDetection write FUseUnicodeWordDetection;
    {$ENDIF}
    // line separators (like \n in Unix)
    property LineSeparators: RegExprString read fLineSeparators write SetLineSeparators; // ###0.941

    // paired line separator (like \r\n in DOS and Windows).
    // must contain exactly two chars or no chars at all
    property LinePairedSeparator: RegExprString read GetLinePairedSeparator write SetLinePairedSeparator; // ###0.941

    // Set this property if you want to override case-insensitive functionality.
    // Create set it to RegExprInvertCaseFunction (InvertCaseFunction by default)
    property InvertCase: TRegExprInvertCaseFunction read fInvertCase write fInvertCase; // ##0.935

    // Use OS line end on replace or not. Default is True for backwards compatibility.
    // Set to false to use #10.
    property UseOsLineEndOnReplace: boolean read FUseOsLineEndOnReplace write SetUseOsLineEndOnReplace;
  end;

  ERegExpr = class(Exception)
  public
    ErrorCode: integer;
    CompilerErrorPos: PtrInt;
  end;

const
  // default for InvertCase property:
  RegExprInvertCaseFunction: TRegExprInvertCaseFunction =
    {$IFDEF FPC} nil {$ELSE} TRegExpr.InvertCaseFunction{$ENDIF};

  // true if string AInputString match regular expression ARegExpr
  // ! will raise exeption if syntax errors in ARegExpr
function ExecRegExpr(const ARegExpr, AInputStr: RegExprString): boolean;

// Split AInputStr into APieces by r.e. ARegExpr occurencies
procedure SplitRegExpr(const ARegExpr, AInputStr: RegExprString;
  APieces: TStrings);

// Returns AInputStr with r.e. occurencies replaced by AReplaceStr
// If AUseSubstitution is true, then AReplaceStr will be used
// as template for Substitution methods.
// For example:
// ReplaceRegExpr ('({-i}block|var)\s*\(\s*([^ ]*)\s*\)\s*',
// 'BLOCK( test1)', 'def "$1" value "$2"', True)
// will return:  def 'BLOCK' value 'test1'
// ReplaceRegExpr ('({-i}block|var)\s*\(\s*([^ ]*)\s*\)\s*',
// 'BLOCK( test1)', 'def "$1" value "$2"')
// will return:  def "$1" value "$2"
function ReplaceRegExpr(const ARegExpr, AInputStr, AReplaceStr: RegExprString;
  AUseSubstitution: boolean{$IFDEF DefParam} = False{$ENDIF}): RegExprString;
{$IFDEF OverMeth}overload; // ###0.947

// Alternate form allowing to set more parameters.

Type
  TRegexReplaceOption = (rroModifierI, rroModifierR, rroModifierS, rroModifierG,
    rroModifierM, rroModifierX, rroUseSubstitution, rroUseOsLineEnd);
  TRegexReplaceOptions = Set of TRegexReplaceOption;

function ReplaceRegExpr(const ARegExpr, AInputStr, AReplaceStr: RegExprString;
  Options: TRegexReplaceOptions): RegExprString; overload;
{$ENDIF}
// Replace all metachars with its safe representation,
// for example 'abc$cd.(' converts into 'abc\$cd\.\('
// This function useful for r.e. autogeneration from
// user input
function QuoteRegExprMetaChars(const AStr: RegExprString): RegExprString;
// Makes list of subexpressions found in ARegExpr r.e.
// In ASubExps every item represent subexpression,
// from first to last, in format:
// String - subexpression text (without '()')
// low word of Object - starting position in ARegExpr, including '('
// if exists! (first position is 1)
// high word of Object - length, including starting '(' and ending ')'
// if exist!
// AExtendedSyntax - must be True if modifier /m will be On while
// using the r.e.
// Useful for GUI editors of r.e. etc (You can find example of using
// in TestRExp.dpr project)
// Returns
// 0      Success. No unbalanced brackets was found;
// -1     There are not enough closing brackets ')';
// -(n+1) At position n was found opening '[' without  //###0.942
// corresponding closing ']';
// n      At position n was found closing bracket ')' without
// corresponding opening '('.
// If Result <> 0, then ASubExpr can contain empty items or illegal ones
function RegExprSubExpressions(const ARegExpr: string; ASubExprs: TStrings;
  AExtendedSyntax: boolean{$IFDEF DefParam} = False{$ENDIF}): PtrInt;

implementation

{$IFDEF FPC}
{$IFDEF UnicodeWordDetection}
uses
  UnicodeData;
{$ENDIF}
{$ELSE}
{$IFDEF D2009}
uses
  System.Character; // System.Character exists since Delphi 2009
{$ENDIF}
{$ENDIF}

const
  // TRegExpr.VersionMajor/Minor return values of these constants:
  TRegExprVersionMajor: integer = 0;
  TRegExprVersionMinor: integer = 964;

  MaskModI = 1; // modifier /i bit in fModifiers
  MaskModR = 2; // -"- /r
  MaskModS = 4; // -"- /s
  MaskModG = 8; // -"- /g
  MaskModM = 16; // -"- /m
  MaskModX = 32; // -"- /x

  {$IFDEF UniCode}
  XIgnoredChars = ' '#9#$d#$a;
  {$ELSE}
  XIgnoredChars = [' ', #9, #$d, #$a];
  {$ENDIF}

function AlignToPtr(const p: Pointer): Pointer; {$IFDEF InlineFuncs}inline;{$ENDIF}
begin
  {$IFDEF FPC_REQUIRES_PROPER_ALIGNMENT}
  Result := Align(p, SizeOf(Pointer));
  {$ELSE}
  Result := p;
  {$ENDIF}
end;

function AlignToInt(const p: Pointer): Pointer; {$IFDEF InlineFuncs}inline;{$ENDIF}
begin
  {$IFDEF FPC_REQUIRES_PROPER_ALIGNMENT}
  Result := Align(p, SizeOf(integer));
  {$ELSE}
  Result := p;
  {$ENDIF}
end;

function _UpperCase(Ch: REChar): REChar;
begin
  Result := Ch;
  if (Ch >= 'a') and (Ch <= 'z') then
  begin
    Dec(Result, 32);
    Exit;
  end;
  if Ord(Ch) < 128 then
    Exit;

  {$IFDEF FPC}
    {$IFDEF UniCode}
    Result := UnicodeUpperCase(Ch)[1];
    {$ELSE}
    Result := AnsiUpperCase(Ch)[1];
    {$ENDIF}
  {$ELSE}
    {$IFDEF UniCode}
    {$IFDEF D2009}
    Result := TCharacter.ToUpper(Ch);
    {$ENDIF}
    {$ELSE}
    Result := AnsiUpperCase(Ch)[1];
    {$ENDIF}
  {$ENDIF}
end;

function _LowerCase(Ch: REChar): REChar;
begin
  Result := Ch;
  if (Ch >= 'A') and (Ch <= 'Z') then
  begin
    Inc(Result, 32);
    Exit;
  end;
  if Ord(Ch) < 128 then
    Exit;

  {$IFDEF FPC}
    {$IFDEF UniCode}
    Result := UnicodeLowerCase(Ch)[1];
    {$ELSE}
    Result := AnsiLowerCase(Ch)[1];
    {$ENDIF}
  {$ELSE}
    {$IFDEF UniCode}
    {$IFDEF D2009}
    Result := TCharacter.ToLower(Ch);
    {$ENDIF}
    {$ELSE}
    Result := AnsiLowerCase(Ch)[1];
    {$ENDIF}
  {$ENDIF}
end;

{ ============================================================= }
{ ===================== Global functions ====================== }
{ ============================================================= }

function ExecRegExpr(const ARegExpr, AInputStr: RegExprString): boolean;
var
  r: TRegExpr;
begin
  r := TRegExpr.Create;
  try
    r.Expression := ARegExpr;
    Result := r.Exec(AInputStr);
  finally
    r.Free;
  end;
end; { of function ExecRegExpr
  -------------------------------------------------------------- }

procedure SplitRegExpr(const ARegExpr, AInputStr: RegExprString;
  APieces: TStrings);
var
  r: TRegExpr;
begin
  APieces.Clear;
  r := TRegExpr.Create;
  try
    r.Expression := ARegExpr;
    r.Split(AInputStr, APieces);
  finally
    r.Free;
  end;
end; { of procedure SplitRegExpr
  -------------------------------------------------------------- }

function ReplaceRegExpr(const ARegExpr, AInputStr, AReplaceStr: RegExprString;
  AUseSubstitution: boolean{$IFDEF DefParam} = False{$ENDIF}): RegExprString;
begin
  with TRegExpr.Create do
    try
      Expression := ARegExpr;
      Result := Replace(AInputStr, AReplaceStr, AUseSubstitution);
    finally
      Free;
    end;
end; { of function ReplaceRegExpr
  -------------------------------------------------------------- }
{$IFDEF OverMeth}

function ReplaceRegExpr(const ARegExpr, AInputStr, AReplaceStr: RegExprString;
  Options: TRegexReplaceOptions): RegExprString; overload;

begin
  with TRegExpr.Create do
    try
      ModifierI := (rroModifierI in Options);
      ModifierR := (rroModifierR in Options);
      ModifierS := (rroModifierS in Options);
      ModifierG := (rroModifierG in Options);
      ModifierM := (rroModifierM in Options);
      ModifierX := (rroModifierX in Options);
      // Set this after the above, if the regex contains modifiers, they will be applied.
      Expression := ARegExpr;
      UseOsLineEndOnReplace := (rroUseOsLineEnd in Options);
      Result := Replace(AInputStr, AReplaceStr, rroUseSubstitution in Options);
    finally
      Free;
    end;
end;
{$ENDIF}

const
  META: RegExprString = '^$.[()|?+*' + EscChar + '{';

function QuoteRegExprMetaChars(const AStr: RegExprString): RegExprString;
var
  MetaAll: RegExprString; // Very similar to META, but slighly changed.
  i, i0, Len: PtrInt;
begin
  Result := '';
  MetaAll := META + ']}';
  Len := length(AStr);
  i := 1;
  i0 := i;
  while i <= Len do
  begin
    if Pos(AStr[i], MetaAll) > 0 then
    begin
      Result := Result + System.Copy(AStr, i0, i - i0) + EscChar + AStr[i];
      i0 := i + 1;
    end;
    Inc(i);
  end;
  Result := Result + System.Copy(AStr, i0, MaxInt); // Tail
end; { of function QuoteRegExprMetaChars
  -------------------------------------------------------------- }

function RegExprSubExpressions(const ARegExpr: string; ASubExprs: TStrings;
  AExtendedSyntax: boolean{$IFDEF DefParam} = False{$ENDIF}): PtrInt;
type
  TStackItemRec = record // ###0.945
    SubExprIdx: integer;
    StartPos: PtrInt;
  end;

  TStackArray = packed array [0 .. NSUBEXPMAX - 1] of TStackItemRec;
var
  Len, SubExprLen: PtrInt;
  i, i0: PtrInt;
  Modif: integer;
  Stack: ^TStackArray; // ###0.945
  StackIdx, StackSz: PtrInt;
begin
  Result := 0; // no unbalanced brackets found at this very moment
  Modif := 0;
  ASubExprs.Clear; // I don't think that adding to non empty list
  // can be useful, so I simplified algorithm to work only with empty list

  Len := length(ARegExpr); // some optimization tricks

  // first we have to calculate number of subexpression to reserve
  // space in Stack array (may be we'll reserve more than needed, but
  // it's faster then memory reallocation during parsing)
  StackSz := 1; // add 1 for entire r.e.
  for i := 1 to Len do
    if ARegExpr[i] = '(' then
      Inc(StackSz);
  // SetLength (Stack, StackSz); //###0.945
  GetMem(Stack, SizeOf(TStackItemRec) * StackSz);
  try

    StackIdx := 0;
    i := 1;
    while (i <= Len) do
    begin
      case ARegExpr[i] of
        '(':
          begin
            if (i < Len) and (ARegExpr[i + 1] = '?') then
            begin
              // this is not subexpression, but comment or other
              // Perl extension. We must check is it (?ismxrg-ismxrg)
              // and change AExtendedSyntax if /x is changed.
              Inc(i, 2); // skip '(?'
              i0 := i;
              while (i <= Len) and (ARegExpr[i] <> ')') do
                Inc(i);
              if i > Len then
                Result := -1 // unbalansed '('
              else if TRegExpr.ParseModifiersStr(System.Copy(ARegExpr, i,
                i - i0), Modif) then
                AExtendedSyntax := (Modif and MaskModX) <> 0;
            end
            else
            begin // subexpression starts
              ASubExprs.Add(''); // just reserve space
              with Stack[StackIdx] do
              begin
                SubExprIdx := ASubExprs.Count - 1;
                StartPos := i;
              end;
              Inc(StackIdx);
            end;
          end;
        ')':
          begin
            if StackIdx = 0 then
              Result := i // unbalanced ')'
            else
            begin
              Dec(StackIdx);
              with Stack[StackIdx] do
              begin
                SubExprLen := i - StartPos + 1;
                ASubExprs.Objects[SubExprIdx] :=
                  TObject(StartPos or (SubExprLen ShL 16));
                ASubExprs[SubExprIdx] := System.Copy(ARegExpr, StartPos + 1,
                  SubExprLen - 2); // add without brackets
              end;
            end;
          end;
        EscChar:
          Inc(i); // skip quoted symbol
        '[':
          begin
            // we have to skip character ranges at once, because they can
            // contain '#', and '#' in it must NOT be recognized as eXtended
            // comment beginning!
            i0 := i;
            Inc(i);
            if ARegExpr[i] = ']' // cannot be 'emty' ranges - this interpretes
            then
              Inc(i); // as ']' by itself
            while (i <= Len) and (ARegExpr[i] <> ']') do
              if ARegExpr[i] = EscChar // ###0.942
              then
                Inc(i, 2) // skip 'escaped' char to prevent stopping at '\]'
              else
                Inc(i);
            if (i > Len) or (ARegExpr[i] <> ']') // ###0.942
            then
              Result := -(i0 + 1); // unbalansed '[' //###0.942
          end;
        '#':
          if AExtendedSyntax then
          begin
            // skip eXtended comments
            while (i <= Len) and (ARegExpr[i] <> #$d) and (ARegExpr[i] <> #$a)
            // do not use [#$d, #$a] due to UniCode compatibility
              do
              Inc(i);
            while (i + 1 <= Len) and
              ((ARegExpr[i + 1] = #$d) or (ARegExpr[i + 1] = #$a)) do
              Inc(i); // attempt to work with different kinds of line separators
            // now we are at the line separator that must be skipped.
          end;
        // here is no 'else' clause - we simply skip ordinary chars
      end; // of case
      Inc(i); // skip scanned char
      // ! can move after Len due to skipping quoted symbol
    end;

    // check brackets balance
    if StackIdx <> 0 then
      Result := -1; // unbalansed '('

    // check if entire r.e. added
    if (ASubExprs.Count = 0) or ((PtrInt(ASubExprs.Objects[0]) and $FFFF) <> 1)
      or (((PtrInt(ASubExprs.Objects[0]) ShR 16) and $FFFF) <> Len)
    // whole r.e. wasn't added because it isn't bracketed
    // well, we add it now:
    then
      ASubExprs.InsertObject(0, ARegExpr, TObject((Len ShL 16) or 1));

  finally
    FreeMem(Stack);
  end;
end; { of function RegExprSubExpressions
  -------------------------------------------------------------- }

const
  OP_MAGIC = TREOp(216); // programm signature

  // name            opcode    opnd? meaning
  OP_EEND = TREOp(0); // -    End of program
  OP_BOL = TREOp(1); // -    Match "" at beginning of line
  OP_EOL = TREOp(2); // -    Match "" at end of line
  OP_ANY = TREOp(3); // -    Match any one character
  OP_ANYOF = TREOp(4); // Str  Match any character in string Str
  OP_ANYBUT = TREOp(5); // Str  Match any char. not in string Str
  OP_BRANCH = TREOp(6); // Node Match this alternative, or the next
  OP_BACK = TREOp(7); // -    Jump backward (Next < 0)
  OP_EXACTLY = TREOp(8); // Str  Match string Str
  OP_NOTHING = TREOp(9); // -    Match empty string
  OP_STAR = TREOp(10); // Node Match this (simple) thing 0 or more times
  OP_PLUS = TREOp(11); // Node Match this (simple) thing 1 or more times
  OP_ANYDIGIT = TREOp(12); // -    Match any digit (equiv [0-9])
  OP_NOTDIGIT = TREOp(13); // -    Match not digit (equiv [0-9])
  OP_ANYLETTER = TREOp(14); // -    Match any letter from property WordChars
  OP_NOTLETTER = TREOp(15); // -    Match not letter from property WordChars
  OP_ANYSPACE = TREOp(16); // -    Match any space char (see property SpaceChars)
  OP_NOTSPACE = TREOp(17); // -    Match not space char (see property SpaceChars)
  OP_BRACES = TREOp(18);
  // Node,Min,Max Match this (simple) thing from Min to Max times.
  // Min and Max are TREBracesArg
  OP_COMMENT = TREOp(19); // -    Comment ;)
  OP_EXACTLYCI = TREOp(20); // Str  Match string Str case insensitive
  OP_ANYOFCI = TREOp(21);
  // Str  Match any character in string Str, case insensitive
  OP_ANYBUTCI = TREOp(22);
  // Str  Match any char. not in string Str, case insensitive
  OP_LOOPENTRY = TREOp(23); // Node Start of loop (Node - LOOP for this loop)
  OP_LOOP = TREOp(24); // Node,Min,Max,LoopEntryJmp - back jump for LOOPENTRY.
  // Min and Max are TREBracesArg
  // Node - next node in sequence,
  // LoopEntryJmp - associated LOOPENTRY node addr
  OP_ANYOFTINYSET = TREOp(25);
  // Chrs Match any one char from Chrs (exactly TinySetLen chars)
  OP_ANYBUTTINYSET = TREOp(26);
  // Chrs Match any one char not in Chrs (exactly TinySetLen chars)
  OP_ANYOFFULLSET = TREOp(27); // Set  Match any one char from set of char
  // - very fast (one CPU instruction !) but takes 32 bytes of p-code
  OP_BSUBEXP = TREOp(28);
  // Idx  Match previously matched subexpression #Idx (stored as REChar) //###0.936
  OP_BSUBEXPCI = TREOp(29); // Idx  -"- in case-insensitive mode

  // Non-Greedy Style Ops //###0.940
  OP_STARNG = TREOp(30); // Same as OP_START but in non-greedy mode
  OP_PLUSNG = TREOp(31); // Same as OP_PLUS but in non-greedy mode
  OP_BRACESNG = TREOp(32); // Same as OP_BRACES but in non-greedy mode
  OP_LOOPNG = TREOp(33); // Same as OP_LOOP but in non-greedy mode

  // Multiline mode \m
  OP_BOLML = TREOp(34); // -    Match "" at beginning of line
  OP_EOLML = TREOp(35); // -    Match "" at end of line
  OP_ANYML = TREOp(36); // -    Match any one character

  // Word boundary
  OP_BOUND = TREOp(37); // Match "" between words //###0.943
  OP_NOTBOUND = TREOp(38); // Match "" not between words //###0.943

  OP_ANYHORZSEP = TREOp(39); // Any horizontal whitespace \h
  OP_NOTHORZSEP = TREOp(40); // Not horizontal whitespace \H
  OP_ANYVERTSEP = TREOp(41); // Any vertical whitespace \v
  OP_NOTVERTSEP = TREOp(42); // Not vertical whitespace \V

  // !!! Change OP_OPEN value if you add new opcodes !!!

  OP_OPEN = TREOp(43); // -    Mark this point in input as start of \n
  // OP_OPEN + 1 is \1, etc.
  OP_CLOSE = TREOp(Ord(OP_OPEN) + NSUBEXP);
  // -    Analogous to OP_OPEN.

  // !!! Don't add new OpCodes after CLOSE !!!

  // We work with p-code through pointers, compatible with PRegExprChar.
  // Note: all code components (TRENextOff, TREOp, TREBracesArg, etc)
  // must have lengths that can be divided by SizeOf (REChar) !
  // A node is TREOp of opcode followed Next "pointer" of TRENextOff type.
  // The Next is a offset from the opcode of the node containing it.
  // An operand, if any, simply follows the node. (Note that much of
  // the code generation knows about this implicit relationship!)
  // Using TRENextOff=PtrInt speed up p-code processing.

  // Opcodes description:
  //
  // BRANCH The set of branches constituting a single choice are hooked
  // together with their "next" pointers, since precedence prevents
  // anything being concatenated to any individual branch. The
  // "next" pointer of the last BRANCH in a choice points to the
  // thing following the whole choice. This is also where the
  // final "next" pointer of each individual branch points; each
  // branch starts with the operand node of a BRANCH node.
  // BACK Normal "next" pointers all implicitly point forward; BACK
  // exists to make loop structures possible.
  // STAR,PLUS,BRACES '?', and complex '*' and '+', are implemented as
  // circular BRANCH structures using BACK. Complex '{min,max}'
  // - as pair LOOPENTRY-LOOP (see below). Simple cases (one
  // character per match) are implemented with STAR, PLUS and
  // BRACES for speed and to minimize recursive plunges.
  // LOOPENTRY,LOOP {min,max} are implemented as special pair
  // LOOPENTRY-LOOP. Each LOOPENTRY initialize loopstack for
  // current level.
  // OPEN,CLOSE are numbered at compile time.

  { ============================================================= }
  { ================== Error handling section =================== }
  { ============================================================= }

const
  reeOk = 0;
  reeCompNullArgument = 100;
  reeCompRegexpTooBig = 101;
  reeCompParseRegTooManyBrackets = 102;
  reeCompParseRegUnmatchedBrackets = 103;
  reeCompParseRegUnmatchedBrackets2 = 104;
  reeCompParseRegJunkOnEnd = 105;
  reePlusStarOperandCouldBeEmpty = 106;
  reeNestedSQP = 107;
  reeBadHexDigit = 108;
  reeInvalidRange = 109;
  reeParseAtomTrailingBackSlash = 110;
  reeNoHexCodeAfterBSlashX = 111;
  reeHexCodeAfterBSlashXTooBig = 112;
  reeUnmatchedSqBrackets = 113;
  reeInternalUrp = 114;
  reeQPSBFollowsNothing = 115;
  reeTrailingBackSlash = 116;
  reeNoLetterAfterBSlashC = 117;
  reeRarseAtomInternalDisaster = 119;
  reeBRACESArgTooBig = 122;
  reeBracesMinParamGreaterMax = 124;
  reeUnclosedComment = 125;
  reeComplexBracesNotImplemented = 126;
  reeUrecognizedModifier = 127;
  reeBadLinePairedSeparator = 128;
  reeRegRepeatCalledInappropriately = 1000;
  reeMatchPrimMemoryCorruption = 1001;
  reeMatchPrimCorruptedPointers = 1002;
  reeNoExpression = 1003;
  reeCorruptedProgram = 1004;
  reeNoInputStringSpecified = 1005;
  reeOffsetMustBeGreaterThen0 = 1006;
  reeExecNextWithoutExec = 1007;
  reeGetInputStringWithoutInputString = 1008;
  reeDumpCorruptedOpcode = 1011;
  reeModifierUnsupported = 1013;
  reeLoopStackExceeded = 1014;
  reeLoopWithoutEntry = 1015;
  reeBadPCodeImported = 2000;

function TRegExpr.ErrorMsg(AErrorID: integer): RegExprString;
begin
  case AErrorID of
    reeOk:
      Result := 'No errors';
    reeCompNullArgument:
      Result := 'TRegExpr(comp): Null Argument';
    reeCompRegexpTooBig:
      Result := 'TRegExpr(comp): Regexp Too Big';
    reeCompParseRegTooManyBrackets:
      Result := 'TRegExpr(comp): ParseReg Too Many ()';
    reeCompParseRegUnmatchedBrackets:
      Result := 'TRegExpr(comp): ParseReg Unmatched ()';
    reeCompParseRegUnmatchedBrackets2:
      Result := 'TRegExpr(comp): ParseReg Unmatched ()';
    reeCompParseRegJunkOnEnd:
      Result := 'TRegExpr(comp): ParseReg Junk On End';
    reePlusStarOperandCouldBeEmpty:
      Result := 'TRegExpr(comp): *+ Operand Could Be Empty';
    reeNestedSQP:
      Result := 'TRegExpr(comp): Nested *?+';
    reeBadHexDigit:
      Result := 'TRegExpr(comp): Bad Hex Digit';
    reeInvalidRange:
      Result := 'TRegExpr(comp): Invalid [] Range';
    reeParseAtomTrailingBackSlash:
      Result := 'TRegExpr(comp): Parse Atom Trailing \';
    reeNoHexCodeAfterBSlashX:
      Result := 'TRegExpr(comp): No Hex Code After \x';
    reeNoLetterAfterBSlashC:
      Result := 'TRegExpr(comp): No Letter "A".."Z" After \c';
    reeHexCodeAfterBSlashXTooBig:
      Result := 'TRegExpr(comp): Hex Code After \x Is Too Big';
    reeUnmatchedSqBrackets:
      Result := 'TRegExpr(comp): Unmatched []';
    reeInternalUrp:
      Result := 'TRegExpr(comp): Internal Urp';
    reeQPSBFollowsNothing:
      Result := 'TRegExpr(comp): ?+*{ Follows Nothing';
    reeTrailingBackSlash:
      Result := 'TRegExpr(comp): Trailing \';
    reeRarseAtomInternalDisaster:
      Result := 'TRegExpr(comp): RarseAtom Internal Disaster';
    reeBRACESArgTooBig:
      Result := 'TRegExpr(comp): BRACES Argument Too Big';
    reeBracesMinParamGreaterMax:
      Result := 'TRegExpr(comp): BRACE Min Param Greater then Max';
    reeUnclosedComment:
      Result := 'TRegExpr(comp): Unclosed (?#Comment)';
    reeComplexBracesNotImplemented:
      Result := 'TRegExpr(comp): If you want take part in beta-testing BRACES ''{min,max}'' and non-greedy ops ''*?'', ''+?'', ''??'' for complex cases - remove ''.'' from {.$DEFINE ComplexBraces}';
    reeUrecognizedModifier:
      Result := 'TRegExpr(comp): Urecognized Modifier';
    reeBadLinePairedSeparator:
      Result := 'TRegExpr(comp): LinePairedSeparator must countain two different chars or no chars at all';

    reeRegRepeatCalledInappropriately:
      Result := 'TRegExpr(exec): RegRepeat Called Inappropriately';
    reeMatchPrimMemoryCorruption:
      Result := 'TRegExpr(exec): MatchPrim Memory Corruption';
    reeMatchPrimCorruptedPointers:
      Result := 'TRegExpr(exec): MatchPrim Corrupted Pointers';
    reeNoExpression:
      Result := 'TRegExpr(exec): Not Assigned Expression Property';
    reeCorruptedProgram:
      Result := 'TRegExpr(exec): Corrupted Program';
    reeNoInputStringSpecified:
      Result := 'TRegExpr(exec): No Input String Specified';
    reeOffsetMustBeGreaterThen0:
      Result := 'TRegExpr(exec): Offset Must Be Greater Then 0';
    reeExecNextWithoutExec:
      Result := 'TRegExpr(exec): ExecNext Without Exec[Pos]';
    reeGetInputStringWithoutInputString:
      Result := 'TRegExpr(exec): GetInputString Without InputString';
    reeDumpCorruptedOpcode:
      Result := 'TRegExpr(dump): Corrupted Opcode';
    reeLoopStackExceeded:
      Result := 'TRegExpr(exec): Loop Stack Exceeded';
    reeLoopWithoutEntry:
      Result := 'TRegExpr(exec): Loop Without LoopEntry !';

    reeBadPCodeImported:
      Result := 'TRegExpr(misc): Bad p-code imported';
  else
    Result := 'Unknown error';
  end;
end; { of procedure TRegExpr.Error
  -------------------------------------------------------------- }

function TRegExpr.LastError: integer;
begin
  Result := fLastError;
  fLastError := reeOk;
end; { of function TRegExpr.LastError
  -------------------------------------------------------------- }

{ ============================================================= }
{ ===================== Common section ======================== }
{ ============================================================= }

class function TRegExpr.VersionMajor: integer; // ###0.944
begin
  Result := TRegExprVersionMajor;
end; { of class function TRegExpr.VersionMajor
  -------------------------------------------------------------- }

class function TRegExpr.VersionMinor: integer; // ###0.944
begin
  Result := TRegExprVersionMinor;
end; { of class function TRegExpr.VersionMinor
  -------------------------------------------------------------- }

constructor TRegExpr.Create;
begin
  inherited;
  programm := nil;
  fExpression := '';
  fInputString := '';

  regexpbeg := nil;
  fExprIsCompiled := False;
  ModifierI := RegExprModifierI;
  ModifierR := RegExprModifierR;
  ModifierS := RegExprModifierS;
  ModifierG := RegExprModifierG;
  ModifierM := RegExprModifierM; // ###0.940

  {$IFDEF UseSpaceChars}
  SpaceChars := RegExprSpaceChars; // ###0.927
  {$ENDIF}
  {$IFDEF UseWordChars}
  WordChars := RegExprWordChars; // ###0.929
  {$ENDIF}
  fInvertCase := RegExprInvertCaseFunction; // ###0.927

  fLineSeparators := RegExprLineSeparators; // ###0.941
  LinePairedSeparator := RegExprLinePairedSeparator; // ###0.941

  FUseOsLineEndOnReplace := True;
  FReplaceLineEnd := sLineBreak;

  fMetaStart := PRegExprChar(META);
  fMetaEnd := fMetaStart + length(META);

  {$IFDEF UnicodeWordDetection}
  FUseUnicodeWordDetection := True;
  {$ENDIF}
end; { of constructor TRegExpr.Create
  -------------------------------------------------------------- }

{$IFDEF OverMeth}
constructor TRegExpr.Create(const AExpression: RegExprString);
begin
  Create;
  Expression := AExpression;
end;
{$ENDIF}

destructor TRegExpr.Destroy;
begin
  if programm <> nil then
  begin
    FreeMem(programm);
    programm := nil;
  end;
end; { of destructor TRegExpr.Destroy
  -------------------------------------------------------------- }

class function TRegExpr.InvertCaseFunction(const Ch: REChar): REChar;
begin
  Result := Ch;
  if (Ch >= 'a') and (Ch <= 'z') then
  begin
    Dec(Result, 32);
    Exit;
  end;
  if (Ch >= 'A') and (Ch <= 'Z') then
  begin
    Inc(Result, 32);
    Exit;
  end;
  if Ord(Ch) < 128 then
    Exit;

  {$IFDEF FPC}
  Result := _UpperCase(Ch);
  if Result = Ch then
    Result := _LowerCase(Ch);
  {$ELSE}
  {$IFDEF UniCode}
  {$IFDEF D2009}
  if TCharacter.IsUpper(Ch) then
    Result := TCharacter.ToLower(Ch)
  else
    Result := TCharacter.ToUpper(Ch);
  {$ENDIF}
  {$ELSE}
  Result := _UpperCase(Ch);
  if Result = Ch then
    Result := _LowerCase(Ch);
  {$ENDIF}
  {$ENDIF}
end; { of function TRegExpr.InvertCaseFunction
  -------------------------------------------------------------- }

procedure TRegExpr.SetExpression(const s: RegExprString);
begin
  if (s <> fExpression) or not fExprIsCompiled then
  begin
    fExprIsCompiled := False;
    fExpression := s;
    UniqueString(fExpression);
    fRegexStart := PRegExprChar(fExpression);
    fRegexEnd := fRegexStart + length(fExpression);
    InvalidateProgramm; // ###0.941
  end;
end; { of procedure TRegExpr.SetExpression
  -------------------------------------------------------------- }

function TRegExpr.GetMatchPos(Idx: integer): PtrInt;
begin
  Idx := FSubExprIndexes[Idx];
  if (Idx >= 0) and (startp[Idx] <> nil) then
    Result := startp[Idx] - fInputStart + 1
  else
    Result := -1;
end; { of function TRegExpr.GetMatchPos
  -------------------------------------------------------------- }

function TRegExpr.GetMatchLen(Idx: integer): PtrInt;
begin
  Idx := FSubExprIndexes[Idx];
  if (Idx >= 0) and (startp[Idx] <> nil) then
    Result := endp[Idx] - startp[Idx]
  else
    Result := -1;
end; { of function TRegExpr.GetMatchLen
  -------------------------------------------------------------- }

function TRegExpr.GetMatch(Idx: integer): RegExprString;
begin
  Result := '';
  Idx := FSubExprIndexes[Idx];
  if (Idx >= 0) and (endp[Idx] > startp[Idx])
  // then Result := copy (fInputString, MatchPos [Idx], MatchLen [Idx]) //###0.929
  then
  begin
    // SetString (Result, startp [idx], endp [idx] - startp [idx])
    SetLength(Result, endp[Idx] - startp[Idx]);
    System.Move(startp[Idx]^, Result[1], length(Result) * SizeOf(REChar));
  end;
end; { of function TRegExpr.GetMatch
  -------------------------------------------------------------- }

function TRegExpr.GetModifierStr: RegExprString;
begin
  Result := '-';

  if ModifierI then
    Result := 'i' + Result
  else
    Result := Result + 'i';
  if ModifierR then
    Result := 'r' + Result
  else
    Result := Result + 'r';
  if ModifierS then
    Result := 's' + Result
  else
    Result := Result + 's';
  if ModifierG then
    Result := 'g' + Result
  else
    Result := Result + 'g';
  if ModifierM then
    Result := 'm' + Result
  else
    Result := Result + 'm';
  if ModifierX then
    Result := 'x' + Result
  else
    Result := Result + 'x';

  if Result[length(Result)] = '-' // remove '-' if all modifiers are 'On'
  then
    System.Delete(Result, length(Result), 1);
end; { of function TRegExpr.GetModifierStr
  -------------------------------------------------------------- }

class function TRegExpr.ParseModifiersStr(const AModifiers: RegExprString;
  var AModifiersInt: integer): boolean;
// !!! Be carefull - this is class function and must not use object instance fields
var
  i: integer;
  IsOn: boolean;
  Mask: integer;
begin
  Result := True;
  IsOn := True;
  Mask := 0; // prevent compiler warning
  for i := 1 to length(AModifiers) do
  begin
    case AModifiers[i] of
      '-':
        IsOn := False;
      'I', 'i':
        Mask := MaskModI;
      'R', 'r':
        Mask := MaskModR;
      'S', 's':
        Mask := MaskModS;
      'G', 'g':
        Mask := MaskModG;
      'M', 'm':
        Mask := MaskModM;
      'X', 'x':
        Mask := MaskModX;
    else
      begin
        Result := False;
        Exit;
      end;
    end;
    if IsOn then
      AModifiersInt := AModifiersInt or Mask
    else
      AModifiersInt := AModifiersInt and not Mask;
  end;
end; { of function TRegExpr.ParseModifiersStr
  -------------------------------------------------------------- }

procedure TRegExpr.SetModifierStr(const AModifiers: RegExprString);
begin
  if not ParseModifiersStr(AModifiers, fModifiers) then
    Error(reeModifierUnsupported);
end; { of procedure TRegExpr.SetModifierStr
  -------------------------------------------------------------- }

function TRegExpr.GetModifier(AIndex: integer): boolean;
var
  Mask: integer;
begin
  Result := False;
  case AIndex of
    1:
      Mask := MaskModI;
    2:
      Mask := MaskModR;
    3:
      Mask := MaskModS;
    4:
      Mask := MaskModG;
    5:
      Mask := MaskModM;
    6:
      Mask := MaskModX;
  else
    begin
      Error(reeModifierUnsupported);
      Exit;
    end;
  end;
  Result := (fModifiers and Mask) <> 0;
end; { of function TRegExpr.GetModifier
  -------------------------------------------------------------- }

procedure TRegExpr.SetModifier(AIndex: integer; ASet: boolean);
var
  Mask: integer;
begin
  case AIndex of
    1:
      Mask := MaskModI;
    2:
      Mask := MaskModR;
    3:
      Mask := MaskModS;
    4:
      Mask := MaskModG;
    5:
      Mask := MaskModM;
    6:
      Mask := MaskModX;
  else
    begin
      Error(reeModifierUnsupported);
      Exit;
    end;
  end;
  if ASet then
    fModifiers := fModifiers or Mask
  else
    fModifiers := fModifiers and not Mask;
end; { of procedure TRegExpr.SetModifier
  -------------------------------------------------------------- }

{ ============================================================= }
{ ==================== Compiler section ======================= }
{ ============================================================= }

{$IFDEF UnicodeWordDetection}
  {$IFDEF FPC}
  function IsUnicodeWordChar(AChar: WideChar): boolean; inline;
  var
    NType: byte;
  begin
    if Ord(AChar) >= LOW_SURROGATE_BEGIN then
      Exit(False);
    NType := GetProps(Ord(AChar))^.Category;
    Result := (NType <= UGC_OtherNumber);
  end;
  {$ELSE}
  function IsUnicodeWordChar(AChar: WideChar): boolean; inline;
  begin
    Result := System.Character.IsLetterOrDigit(AChar);
  end;
  {$ENDIF}
{$ENDIF}

function TRegExpr.IsWordChar(AChar: REChar): boolean;
begin
  {$IFDEF UseWordChars}
  Result := Pos(AChar, fWordChars) > 0;
  {$ELSE}
  case AChar of
    'a' .. 'z',
    'A' .. 'Z',
    '0' .. '9', '_':
      Result := True
    else
      Result := False;
  end;
  {$ENDIF}
  {$IFDEF UnicodeWordDetection}
  if not Result and (Ord(AChar) >= 128) and UseUnicodeWordDetection then
    Result := IsUnicodeWordChar(AChar);
  {$ENDIF}
end;

function TRegExpr.IsSpaceChar(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline;{$ENDIF}
begin
  {$IFDEF UseSpaceChars}
  Result := Pos(AChar^, fSpaceChars) > 0;
  {$ELSE}
  case AChar of
    ' ', #$9, #$A, #$D, #$C:
      Result := True
    else
      Result := False;
  end;
  {$ENDIF}
end;

function TRegExpr.IsDigitChar(AChar: REChar): boolean; {$IFDEF InlineFuncs}inline;{$ENDIF}
begin
  case AChar of
    '0' .. '9':
      Result := True;
  else
    Result := False;
  end;
end;

function TRegExpr.IsHorzSeparator(AChar: REChar): boolean;
begin
  // Tab and Unicode categoty "Space Separator": https://www.compart.com/en/unicode/category/Zs
  case AChar of
    #9, #$20, #$A0:
      Result := True;
    {$IFDEF UniCode}
    #$1680, #$2000 .. #$200A, #$202F, #$205F, #$3000:
      Result := True;
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TRegExpr.IsLineSeparator(AChar: REChar): boolean;
begin
  case AChar of
    #$d, #$a, #$b, #$c:
      Result := True;
    {$IFDEF UniCode}
    #$2028, #$2029, #$85:
      Result := True;
    {$ENDIF}
  else
    Result := False;
  end;
end;

procedure TRegExpr.InvalidateProgramm;
begin
  if programm <> nil then
  begin
    FreeMem(programm);
    programm := nil;
  end;
end; { of procedure TRegExpr.InvalidateProgramm
  -------------------------------------------------------------- }

procedure TRegExpr.Compile; // ###0.941
begin
  if fExpression = '' then
  begin // No Expression assigned
    Error(reeNoExpression);
    Exit;
  end;
  CompileRegExpr(PRegExprChar(fExpression));
end; { of procedure TRegExpr.Compile
  -------------------------------------------------------------- }

function TRegExpr.IsProgrammOk: boolean;
{$IFNDEF UniCode}
var
  i: integer;
{$ENDIF}
begin
  Result := False;

  // check modifiers
  if fModifiers <> fProgModifiers // ###0.941
  then
    InvalidateProgramm;

  // can we optimize line separators by using sets?
  {$IFNDEF UniCode}
  fLineSeparatorsSet := [];
  for i := 1 to length(fLineSeparators) do
    System.Include(fLineSeparatorsSet, fLineSeparators[i]);
  {$ENDIF}
  // [Re]compile if needed
  if programm = nil then
    Compile; // ###0.941

  // check [re]compiled programm
  if programm = nil then
    Exit // error was set/raised by Compile (was reeExecAfterCompErr)
  else if programm[0] <> OP_MAGIC // Program corrupted.
  then
    Error(reeCorruptedProgram)
  else
    Result := True;
end; { of function TRegExpr.IsProgrammOk
  -------------------------------------------------------------- }

procedure TRegExpr.Tail(p: PRegExprChar; val: PRegExprChar);
// set the next-pointer at the end of a node chain
var
  scan: PRegExprChar;
  temp: PRegExprChar;
  // i : int64;
begin
  if p = @regdummy then
    Exit;
  // Find last node.
  scan := p;
  repeat
    temp := regnext(scan);
    if temp = nil then
      Break;
    scan := temp;
  until False;
  // Set Next 'pointer'
  if val < scan then
    PRENextOff(AlignToPtr(scan + REOpSz))^ := -(scan - val) // ###0.948
    // work around PWideChar subtraction bug (Delphi uses
    // shr after subtraction to calculate widechar distance %-( )
    // so, if difference is negative we have .. the "feature" :(
    // I could wrap it in $IFDEF UniCode, but I didn't because
    // "P – Q computes the difference between the address given
    // by P (the higher address) and the address given by Q (the
    // lower address)" - Delphi help quotation.
  else
    PRENextOff(AlignToPtr(scan + REOpSz))^ := val - scan; // ###0.933
end; { of procedure TRegExpr.Tail
  -------------------------------------------------------------- }

procedure TRegExpr.OpTail(p: PRegExprChar; val: PRegExprChar);
// regtail on operand of first argument; nop if operandless
begin
  // "Operandless" and "op != OP_BRANCH" are synonymous in practice.
  if (p = nil) or (p = @regdummy) or (PREOp(p)^ <> OP_BRANCH) then
    Exit;
  Tail(p + REOpSz + RENextOffSz, val); // ###0.933
end; { of procedure TRegExpr.OpTail
  -------------------------------------------------------------- }

function TRegExpr.EmitNode(op: TREOp): PRegExprChar; // ###0.933
// emit a node, return location
begin
  Result := regcode;
  if Result <> @regdummy then
  begin
    PREOp(regcode)^ := op;
    Inc(regcode, REOpSz);
    PRENextOff(AlignToPtr(regcode))^ := 0; // Next "pointer" := nil
    Inc(regcode, RENextOffSz);
    {$IFDEF DebugSynRegExpr}
    if regcode - programm > regsize then
      raise Exception.Create('TRegExpr.EmitNode buffer overrun');
    {$ENDIF}
  end
  else
    Inc(regsize, REOpSz + RENextOffSz);
  // compute code size without code generation
end; { of function TRegExpr.EmitNode
  -------------------------------------------------------------- }

procedure TRegExpr.EmitC(b: REChar);
// emit a byte to code
begin
  if regcode <> @regdummy then
  begin
    regcode^ := b;
    Inc(regcode);
    {$IFDEF DebugSynRegExpr}
    if regcode - programm > regsize then
      raise Exception.Create('TRegExpr.EmitC buffer overrun');
    {$ENDIF}
  end
  else
    Inc(regsize, REOpSz); // Type of p-code pointer always is ^REChar
end; { of procedure TRegExpr.EmitC
  -------------------------------------------------------------- }

procedure TRegExpr.InsertOperator(op: TREOp; opnd: PRegExprChar; sz: integer);
// insert an operator in front of already-emitted operand
// Means relocating the operand.
var
  src, dst, place: PRegExprChar;
  i: integer;
begin
  if regcode = @regdummy then
  begin
    Inc(regsize, sz);
    Exit;
  end;
  // move code behind insert position
  src := regcode;
  Inc(regcode, sz);
  {$IFDEF DebugSynRegExpr}
  if regcode - programm > regsize then
    raise Exception.Create('TRegExpr.InsertOperator buffer overrun');
  // if (opnd<regcode) or (opnd-regcode>regsize) then
  // raise Exception.Create('TRegExpr.InsertOperator invalid opnd');
  {$ENDIF}
  dst := regcode;
  while src > opnd do
  begin
    Dec(dst);
    Dec(src);
    dst^ := src^;
  end;
  place := opnd; // Op node, where operand used to be.
  PREOp(place)^ := op;
  Inc(place, REOpSz);
  for i := 1 + REOpSz to sz do
  begin
    place^ := #0;
    Inc(place);
  end;
end; { of procedure TRegExpr.InsertOperator
  -------------------------------------------------------------- }

function FindInitLen(s1, s2, end1, end2: PRegExprChar): PtrInt;
// find length of initial segment of s1 consisting
// entirely of characters not from s2
var
  scan1, scan2: PRegExprChar;
begin
  Result := 0;
  scan1 := s1;
  while scan1 < end1 do
  begin
    scan2 := s2;
    while scan2 < end2 do
      if scan1^ = scan2^ then
        Exit
      else
        Inc(scan2);
    Inc(Result);
    Inc(scan1)
  end;
end; { of function strcspn
  -------------------------------------------------------------- }

const
  // Flags to be passed up and down.
  flag_HasWidth = 01; // Known never to match nil string.
  flag_Simple = 02; // Simple enough to be OP_STAR/OP_PLUS/OP_BRACES operand.
  flag_SpecStart = 04; // Starts with * or +.
  flag_Worst = 0; // Worst case.

  {$IFDEF UniCode}
  RusRangeLo: array [0 .. 33] of REChar = (#$430, #$431, #$432, #$433, #$434,
    #$435, #$451, #$436, #$437, #$438, #$439, #$43A, #$43B, #$43C, #$43D, #$43E,
    #$43F, #$440, #$441, #$442, #$443, #$444, #$445, #$446, #$447, #$448, #$449,
    #$44A, #$44B, #$44C, #$44D, #$44E, #$44F, #0);
  RusRangeHi: array [0 .. 33] of REChar = (#$410, #$411, #$412, #$413, #$414,
    #$415, #$401, #$416, #$417, #$418, #$419, #$41A, #$41B, #$41C, #$41D, #$41E,
    #$41F, #$420, #$421, #$422, #$423, #$424, #$425, #$426, #$427, #$428, #$429,
    #$42A, #$42B, #$42C, #$42D, #$42E, #$42F, #0);
  RusRangeLoLow = #$430 { 'а' };
  RusRangeLoHigh = #$44F { 'я' };
  RusRangeHiLow = #$410 { 'А' };
  RusRangeHiHigh = #$42F { 'Я' };
  {$ELSE}
  RusRangeLo = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
  RusRangeHi = 'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ';
  RusRangeLoLow = 'а';
  RusRangeLoHigh = 'я';
  RusRangeHiLow = 'А';
  RusRangeHiHigh = 'Я';
  {$ENDIF}

procedure TRegExpr.ClearInternalIndexes;
var
  i: integer;
begin
  for i := 0 to NSUBEXP - 1 do
  begin
    startp[i] := nil;
    endp[i] := nil;
    FSubExprIndexes[i] := -1;
  end;
  FSubExprIndexes[0] := 0;
  FSubExprCount := 0;
end;

function TRegExpr.CompileRegExpr(exp: PRegExprChar): boolean;
// Compile a regular expression into internal code
// We can't allocate space until we know how big the compiled form will be,
// but we can't compile it (and thus know how big it is) until we've got a
// place to put the code. So we cheat: we compile it twice, once with code
// generation turned off and size counting turned on, and once "for real".
// This also means that we don't allocate space until we are sure that the
// thing really will compile successfully, and we never have to move the
// code and thus invalidate pointers into it. (Note that it has to be in
// one piece because free() must be able to free it all.)
// Beware that the optimization-preparation code in here knows about some
// of the structure of the compiled regexp.
var
  scan, longest: PRegExprChar;
  Len: PtrUInt;
  flags: integer;
begin
  Result := False; // life too dark
  flags := 0;
  regparse := nil; // for correct error handling
  regexpbeg := exp;

  ClearInternalIndexes;

  try

    if programm <> nil then
    begin
      FreeMem(programm);
      programm := nil;
    end;

    if exp = nil then
    begin
      Error(reeCompNullArgument);
      Exit;
    end;

    fProgModifiers := fModifiers;
    // well, may it's paranoia. I'll check it later... !!!!!!!!

    // First pass: determine size, legality.
    fSecondPass := False;
    fCompModifiers := fModifiers;
    regparse := exp;
    regnpar := 1;
    regsize := 0;
    regcode := @regdummy;
    EmitC(OP_MAGIC);
    if ParseReg(0, flags) = nil then
      Exit;

    // Allocate space.
    GetMem(programm, regsize * SizeOf(REChar));

    // Second pass: emit code.
    fSecondPass := True;
    fCompModifiers := fModifiers;
    regparse := exp;
    regnpar := 1;
    regcode := programm;
    EmitC(OP_MAGIC);
    if ParseReg(0, flags) = nil then
      Exit;

    // Dig out information for optimizations.
    {$IFDEF UseFirstCharSet} // ###0.929
    FirstCharSet := [];
    FillFirstCharSet(programm + REOpSz);
    {$ENDIF}
    regstart := #0; // Worst-case defaults.
    reganch := #0;
    regmust := nil;
    regmlen := 0;
    scan := programm + REOpSz; // First OP_BRANCH.
    if PREOp(regnext(scan))^ = OP_EEND then
    begin // Only one top-level choice.
      scan := scan + REOpSz + RENextOffSz;

      // Starting-point info.
      if PREOp(scan)^ = OP_EXACTLY then
        regstart := (scan + REOpSz + RENextOffSz)^
      else if PREOp(scan)^ = OP_BOL then
        Inc(reganch);

      // If there's something expensive in the r.e., find the longest
      // literal string that must appear and make it the regmust. Resolve
      // ties in favor of later strings, since the regstart check works
      // with the beginning of the r.e. and avoiding duplication
      // strengthens checking. Not a strong reason, but sufficient in the
      // absence of others.
      if (flags and flag_SpecStart) <> 0 then
      begin
        longest := nil;
        Len := 0;
        while scan <> nil do
        begin
          if (PREOp(scan)^ = OP_EXACTLY) and
            (strlen(scan + REOpSz + RENextOffSz) >= PtrInt(Len)) then
          begin
            longest := scan + REOpSz + RENextOffSz;
            Len := strlen(longest);
          end;
          scan := regnext(scan);
        end;
        regmust := longest;
        regmlen := Len;
      end;
    end;

    Result := True;

  finally
    begin
      if not Result then
        InvalidateProgramm;
      regexpbeg := nil;
      fExprIsCompiled := Result; // ###0.944
    end;
  end;

end; { of function TRegExpr.CompileRegExpr
  -------------------------------------------------------------- }

procedure TRegExpr.SetUseOsLineEndOnReplace(AValue: boolean);
begin
  if FUseOsLineEndOnReplace = AValue then
    Exit;
  FUseOsLineEndOnReplace := AValue;
  if FUseOsLineEndOnReplace then
    FReplaceLineEnd := sLineBreak
  else
    FReplaceLineEnd := #10;
end;

function TRegExpr.ParseReg(paren: integer; var flagp: integer): PRegExprChar;
// regular expression, i.e. main body or parenthesized thing
// Caller must absorb opening parenthesis.
// Combining parenthesis handling with the base level of regular expression
// is a trifle forced, but the need to tie the tails of the branches to what
// follows makes it hard to avoid.
var
  ret, br, ender: PRegExprChar;
  parno: integer;
  flags: integer;
  SavedModifiers: integer;
begin
  flags := 0;
  Result := nil;
  flagp := flag_HasWidth; // Tentatively.
  parno := 0; // eliminate compiler stupid warning
  SavedModifiers := fCompModifiers;

  // Make an OP_OPEN node, if parenthesized.
  if paren <> 0 then
  begin
    if regnpar >= NSUBEXP then
    begin
      Error(reeCompParseRegTooManyBrackets);
      Exit;
    end;
    parno := regnpar;
    Inc(regnpar);
    ret := EmitNode(TREOp(Ord(OP_OPEN) + parno));
  end
  else
    ret := nil;

  // Pick up the branches, linking them together.
  br := ParseBranch(flags);
  if br = nil then
  begin
    Result := nil;
    Exit;
  end;
  if ret <> nil then
    Tail(ret, br) // OP_OPEN -> first.
  else
    ret := br;
  if (flags and flag_HasWidth) = 0 then
    flagp := flagp and not flag_HasWidth;
  flagp := flagp or flags and flag_SpecStart;
  while (regparse^ = '|') do
  begin
    Inc(regparse);
    br := ParseBranch(flags);
    if br = nil then
    begin
      Result := nil;
      Exit;
    end;
    Tail(ret, br); // OP_BRANCH -> OP_BRANCH.
    if (flags and flag_HasWidth) = 0 then
      flagp := flagp and not flag_HasWidth;
    flagp := flagp or flags and flag_SpecStart;
  end;

  // Make a closing node, and hook it on the end.
  if paren <> 0 then
    ender := EmitNode(TREOp(Ord(OP_CLOSE) + parno))
  else
    ender := EmitNode(OP_EEND);
  Tail(ret, ender);

  // Hook the tails of the branches to the closing node.
  br := ret;
  while br <> nil do
  begin
    OpTail(br, ender);
    br := regnext(br);
  end;

  // Check for proper termination.
  if paren <> 0 then
    if regparse^ <> ')' then
    begin
      Error(reeCompParseRegUnmatchedBrackets);
      Exit;
    end
    else
      Inc(regparse); // skip trailing ')'
  if (paren = 0) and (regparse < fRegexEnd) then
  begin
    if regparse^ = ')' then
      Error(reeCompParseRegUnmatchedBrackets2)
    else
      Error(reeCompParseRegJunkOnEnd);
    Exit;
  end;
  fCompModifiers := SavedModifiers; // restore modifiers of parent
  Result := ret;
end; { of function TRegExpr.ParseReg
  -------------------------------------------------------------- }

function TRegExpr.ParseBranch(var flagp: integer): PRegExprChar;
// one alternative of an | operator
// Implements the concatenation operator.
var
  ret, chain, latest: PRegExprChar;
  flags: integer;
begin
  flags := 0;
  flagp := flag_Worst; // Tentatively.

  ret := EmitNode(OP_BRANCH);
  chain := nil;
  while (regparse < fRegexEnd) and (regparse^ <> '|') and (regparse^ <> ')') do
  begin
    latest := ParsePiece(flags);
    if latest = nil then
    begin
      Result := nil;
      Exit;
    end;
    flagp := flagp or flags and flag_HasWidth;
    if chain = nil // First piece.
    then
      flagp := flagp or flags and flag_SpecStart
    else
      Tail(chain, latest);
    chain := latest;
  end;
  if chain = nil // OP_LOOP ran zero times.
  then
    EmitNode(OP_NOTHING);
  Result := ret;
end; { of function TRegExpr.ParseBranch
  -------------------------------------------------------------- }

function TRegExpr.ParsePiece(var flagp: integer): PRegExprChar;
// something followed by possible [*+?{]
// Note that the branching code sequences used for ? and the general cases
// of * and + and { are somewhat optimized:  they use the same OP_NOTHING node as
// both the endmarker for their OP_BRANCH list and the body of the last OP_BRANCH.
// It might seem that this node could be dispensed with entirely, but the
// endmarker role is not redundant.
  function parsenum(AStart, AEnd: PRegExprChar): TREBracesArg;
  begin
    Result := 0;
    if AEnd - AStart + 1 > 8 then
    begin // prevent stupid scanning
      Error(reeBRACESArgTooBig);
      Exit;
    end;
    while AStart <= AEnd do
    begin
      Result := Result * 10 + (Ord(AStart^) - Ord('0'));
      Inc(AStart);
    end;
    if (Result > MaxBracesArg) or (Result < 0) then
    begin
      Error(reeBRACESArgTooBig);
      Exit;
    end;
  end;

var
  op: REChar;
  NonGreedyOp, NonGreedyCh: boolean; // ###0.940
  TheOp: TREOp; // ###0.940
  NextNode: PRegExprChar;
  flags: integer;
  BracesMin, Bracesmax: TREBracesArg;
  p, savedparse: PRegExprChar;

  procedure EmitComplexBraces(ABracesMin, ABracesMax: TREBracesArg;
    ANonGreedyOp: boolean); // ###0.940
  {$IFDEF ComplexBraces}
  var
    off: TRENextOff;
  {$ENDIF}
  begin
    {$IFNDEF ComplexBraces}
    Error(reeComplexBracesNotImplemented);
    {$ELSE}
    if ANonGreedyOp then
      TheOp := OP_LOOPNG
    else
      TheOp := OP_LOOP;
    InsertOperator(OP_LOOPENTRY, Result, REOpSz + RENextOffSz);
    NextNode := EmitNode(TheOp);
    if regcode <> @regdummy then
    begin
      off := (Result + REOpSz + RENextOffSz) - (regcode - REOpSz - RENextOffSz);
      // OP_BACK to Atom after OP_LOOPENTRY
      PREBracesArg(AlignToInt(regcode))^ := ABracesMin;
      Inc(regcode, REBracesArgSz);
      PREBracesArg(AlignToInt(regcode))^ := ABracesMax;
      Inc(regcode, REBracesArgSz);
      PRENextOff(AlignToPtr(regcode))^ := off;
      Inc(regcode, RENextOffSz);
      {$IFDEF DebugSynRegExpr}
      if regcode - programm > regsize then
        raise Exception.Create
          ('TRegExpr.ParsePiece.EmitComplexBraces buffer overrun');
      {$ENDIF}
    end
    else
      Inc(regsize, REBracesArgSz * 2 + RENextOffSz);
    Tail(Result, NextNode); // OP_LOOPENTRY -> OP_LOOP
    if regcode <> @regdummy then
      Tail(Result + REOpSz + RENextOffSz, NextNode); // Atom -> OP_LOOP
    {$ENDIF}
  end;

  procedure EmitSimpleBraces(ABracesMin, ABracesMax: TREBracesArg;
    ANonGreedyOp: boolean); // ###0.940
  begin
    if ANonGreedyOp // ###0.940
    then
      TheOp := OP_BRACESNG
    else
      TheOp := OP_BRACES;
    InsertOperator(TheOp, Result, REOpSz + RENextOffSz + REBracesArgSz * 2);
    if regcode <> @regdummy then
    begin
      PREBracesArg(AlignToInt(Result + REOpSz + RENextOffSz))^ := ABracesMin;
      PREBracesArg(AlignToInt(Result + REOpSz + RENextOffSz + REBracesArgSz))^
        := ABracesMax;
    end;
  end;

begin
  flags := 0;
  Result := ParseAtom(flags);
  if Result = nil then
    Exit;

  op := regparse^;
  if not((op = '*') or (op = '+') or (op = '?') or (op = '{')) then
  begin
    flagp := flags;
    Exit;
  end;
  if ((flags and flag_HasWidth) = 0) and (op <> '?') then
  begin
    Error(reePlusStarOperandCouldBeEmpty);
    Exit;
  end;

  case op of
    '*':
      begin
        flagp := flag_Worst or flag_SpecStart;
        NonGreedyCh := (regparse + 1)^ = '?'; // ###0.940
        NonGreedyOp := NonGreedyCh or ((fCompModifiers and MaskModG) = 0);
        // ###0.940
        if (flags and flag_Simple) = 0 then
        begin
          if NonGreedyOp // ###0.940
          then
            EmitComplexBraces(0, MaxBracesArg, NonGreedyOp)
          else
          begin // Emit x* as (x&|), where & means "self".
            InsertOperator(OP_BRANCH, Result, REOpSz + RENextOffSz); // Either x
            OpTail(Result, EmitNode(OP_BACK)); // and OP_LOOP
            OpTail(Result, Result); // OP_BACK
            Tail(Result, EmitNode(OP_BRANCH)); // or
            Tail(Result, EmitNode(OP_NOTHING)); // nil.
          end
        end
        else
        begin // Simple
          if NonGreedyOp // ###0.940
          then
            TheOp := OP_STARNG
          else
            TheOp := OP_STAR;
          InsertOperator(TheOp, Result, REOpSz + RENextOffSz);
        end;
        if NonGreedyCh // ###0.940
        then
          Inc(regparse); // Skip extra char ('?')
      end; { of case '*' }
    '+':
      begin
        flagp := flag_Worst or flag_SpecStart or flag_HasWidth;
        NonGreedyCh := (regparse + 1)^ = '?'; // ###0.940
        NonGreedyOp := NonGreedyCh or ((fCompModifiers and MaskModG) = 0);
        // ###0.940
        if (flags and flag_Simple) = 0 then
        begin
          if NonGreedyOp // ###0.940
          then
            EmitComplexBraces(1, MaxBracesArg, NonGreedyOp)
          else
          begin // Emit x+ as x(&|), where & means "self".
            NextNode := EmitNode(OP_BRANCH); // Either
            Tail(Result, NextNode);
            Tail(EmitNode(OP_BACK), Result); // OP_LOOP OP_BACK
            Tail(NextNode, EmitNode(OP_BRANCH)); // or
            Tail(Result, EmitNode(OP_NOTHING)); // nil.
          end
        end
        else
        begin // Simple
          if NonGreedyOp // ###0.940
          then
            TheOp := OP_PLUSNG
          else
            TheOp := OP_PLUS;
          InsertOperator(TheOp, Result, REOpSz + RENextOffSz);
        end;
        if NonGreedyCh // ###0.940
        then
          Inc(regparse); // Skip extra char ('?')
      end; { of case '+' }
    '?':
      begin
        flagp := flag_Worst;
        NonGreedyCh := (regparse + 1)^ = '?'; // ###0.940
        NonGreedyOp := NonGreedyCh or ((fCompModifiers and MaskModG) = 0);
        // ###0.940
        if NonGreedyOp then
        begin // ###0.940  // We emit x?? as x{0,1}?
          if (flags and flag_Simple) = 0 then
            EmitComplexBraces(0, 1, NonGreedyOp)
          else
            EmitSimpleBraces(0, 1, NonGreedyOp);
        end
        else
        begin // greedy '?'
          InsertOperator(OP_BRANCH, Result, REOpSz + RENextOffSz); // Either x
          Tail(Result, EmitNode(OP_BRANCH)); // or
          NextNode := EmitNode(OP_NOTHING); // nil.
          Tail(Result, NextNode);
          OpTail(Result, NextNode);
        end;
        if NonGreedyCh // ###0.940
        then
          Inc(regparse); // Skip extra char ('?')
      end; { of case '?' }
    '{':
      begin
        savedparse := regparse;
        // !!!!!!!!!!!!
        // Filip Jirsak's note - what will happen, when we are at the end of regparse?
        Inc(regparse);
        p := regparse;
        while IsDigitChar(regparse^) do // <min> MUST appear
          Inc(regparse);
        if (regparse^ <> '}') and (regparse^ <> ',') or (p = regparse) then
        begin
          regparse := savedparse;
          flagp := flags;
          Exit;
        end;
        BracesMin := parsenum(p, regparse - 1);
        if regparse^ = ',' then
        begin
          Inc(regparse);
          p := regparse;
          while IsDigitChar(regparse^) do
            Inc(regparse);
          if regparse^ <> '}' then
          begin
            regparse := savedparse;
            Exit;
          end;
          if p = regparse then
            Bracesmax := MaxBracesArg
          else
            Bracesmax := parsenum(p, regparse - 1);
        end
        else
          Bracesmax := BracesMin; // {n} == {n,n}
        if BracesMin > Bracesmax then
        begin
          Error(reeBracesMinParamGreaterMax);
          Exit;
        end;
        if BracesMin > 0 then
          flagp := flag_Worst;
        if Bracesmax > 0 then
          flagp := flagp or flag_HasWidth or flag_SpecStart;

        NonGreedyCh := (regparse + 1)^ = '?'; // ###0.940
        NonGreedyOp := NonGreedyCh or ((fCompModifiers and MaskModG) = 0);
        // ###0.940
        if (flags and flag_Simple) <> 0 then
          EmitSimpleBraces(BracesMin, Bracesmax, NonGreedyOp)
        else
          EmitComplexBraces(BracesMin, Bracesmax, NonGreedyOp);
        if NonGreedyCh // ###0.940
        then
          Inc(regparse); // Skip extra char '?'
      end; // of case '{'
    // else // here we can't be
  end; { of case op }

  Inc(regparse);
  if (regparse^ = '*') or (regparse^ = '+') or (regparse^ = '?') or
    (regparse^ = '{') then
  begin
    Error(reeNestedSQP);
    Exit;
  end;
end; { of function TRegExpr.ParsePiece
  -------------------------------------------------------------- }

function TRegExpr.HexDig(Ch: REChar): PtrInt;
begin
  Result := 0;
  if (Ch >= 'a') and (Ch <= 'f') then
    Ch := REChar(Ord(Ch) - (Ord('a') - Ord('A')));
  if (Ch < '0') or (Ch > 'F') or ((Ch > '9') and (Ch < 'A')) then
  begin
    Error(reeBadHexDigit);
    Exit;
  end;
  Result := Ord(Ch) - Ord('0');
  if Ch >= 'A' then
    Result := Result - (Ord('A') - Ord('9') - 1);
end;

function TRegExpr.UnQuoteChar(var APtr: PRegExprChar): REChar;
var
  Ch: REChar;
begin
  case APtr^ of
    't':
      Result := #$9; // \t => tab (HT/TAB)
    'n':
      Result := #$a; // \n => newline (NL)
    'r':
      Result := #$d; // \r => carriage return (CR)
    'f':
      Result := #$c; // \f => form feed (FF)
    'a':
      Result := #$7; // \a => alarm (bell) (BEL)
    'e':
      Result := #$1b; // \e => escape (ESC)
    'c':
      begin // \cK => code for Ctrl+K
        Inc(APtr);
        if APtr >= fRegexEnd then
        begin
          Error(reeNoLetterAfterBSlashC);
          Exit;
        end;
        Ch := APtr^;
        if (Ch >= 'a') and (Ch <= 'z') then // fast UpCase
          Dec(Ch, 32);
        if (Ch < 'A') or (Ch > 'Z') then
        begin
          Error(reeNoLetterAfterBSlashC);
          Exit;
        end;
        Result := REChar(Ord(Ch) - Ord('A') + 1);
      end;
    'x':
      begin // \x: hex char
        Result := #0;
        Inc(APtr);
        if APtr >= fRegexEnd then
        begin
          Error(reeNoHexCodeAfterBSlashX);
          Exit;
        end;
        if APtr^ = '{' then
        begin // \x{nnnn} //###0.936
          repeat
            Inc(APtr);
            if APtr >= fRegexEnd then
            begin
              Error(reeNoHexCodeAfterBSlashX);
              Exit;
            end;
            if APtr^ <> '}' then
            begin
              if (Ord(Result) ShR (SizeOf(REChar) * 8 - 4)) and $F <> 0 then
              begin
                Error(reeHexCodeAfterBSlashXTooBig);
                Exit;
              end;
              Result := REChar((Ord(Result) ShL 4) or HexDig(APtr^));
              // HexDig will cause Error if bad hex digit found
            end
            else
              Break;
          until False;
        end
        else
        begin
          Result := REChar(HexDig(APtr^));
          // HexDig will cause Error if bad hex digit found
          Inc(APtr);
          if APtr >= fRegexEnd then
          begin
            Error(reeNoHexCodeAfterBSlashX);
            Exit;
          end;
          Result := REChar((Ord(Result) ShL 4) or HexDig(APtr^));
          // HexDig will cause Error if bad hex digit found
        end;
      end;
  else
    Result := APtr^;
  end;
end;

function TRegExpr.ParseAtom(var flagp: integer): PRegExprChar;
// the lowest level
// Optimization:  gobbles an entire sequence of ordinary characters so that
// it can turn them into a single node, which is smaller to store and
// faster to run. Backslashed characters are exceptions, each becoming a
// separate node; the code is simpler that way and it's not worth fixing.
var
  ret: PRegExprChar;
  flags: integer;
  RangeBeg, RangeEnd: REChar;
  CanBeRange: boolean;
  Len: PtrInt;
  ender: REChar;
  begmodfs: PRegExprChar;

  {$IFDEF UseSetOfChar} // ###0.930
  RangePCodeBeg: PRegExprChar;
  RangePCodeIdx: PtrInt;
  RangeIsCI: boolean;
  RangeSet: TSetOfREChar;
  RangeLen: PtrInt;
  RangeChMin, RangeChMax: REChar;
  {$ENDIF}

  procedure EmitExactly(Ch: REChar);
  begin
    if (fCompModifiers and MaskModI) <> 0 then
      ret := EmitNode(OP_EXACTLYCI)
    else
      ret := EmitNode(OP_EXACTLY);
    EmitC(Ch);
    EmitC(#0);
    flagp := flagp or flag_HasWidth or flag_Simple;
  end;

  procedure EmitStr(const s: RegExprString);
  var
    i: PtrInt;
  begin
    for i := 1 to length(s) do
      EmitC(s[i]);
  end;

  function EmitRange(AOpCode: REChar): PRegExprChar;
  begin
    {$IFDEF UseSetOfChar}
    case AOpCode of
      OP_ANYBUTCI, OP_ANYBUT:
        Result := EmitNode(OP_ANYBUTTINYSET);
    else // OP_ANYOFCI, OP_ANYOF
      Result := EmitNode(OP_ANYOFTINYSET);
    end;
    case AOpCode of
      OP_ANYBUTCI, OP_ANYOFCI:
        RangeIsCI := True;
    else // OP_ANYBUT, OP_ANYOF
      RangeIsCI := False;
    end;
    RangePCodeBeg := regcode;
    RangePCodeIdx := regsize;
    RangeLen := 0;
    RangeSet := [];
    RangeChMin := #255;
    RangeChMax := #0;
    {$ELSE}
    Result := EmitNode(AOpCode);
    // ToDo:
    // !!!!!!!!!!!!! Implement ANYOF[BUT]TINYSET generation for UniCode !!!!!!!!!!
    {$ENDIF}
  end;

  {$IFDEF UseSetOfChar}
  procedure EmitRangeCPrim(b: REChar); // ###0.930
  begin
    if b in RangeSet then
      Exit;
    Inc(RangeLen);
    if b < RangeChMin then
      RangeChMin := b;
    if b > RangeChMax then
      RangeChMax := b;
    Include(RangeSet, b);
  end;
  {$ENDIF}

  procedure EmitRangeC(b: REChar);
  {$IFDEF UseSetOfChar}
  var
    Ch: REChar;
  {$ENDIF}
  begin
    CanBeRange := False;
    {$IFDEF UseSetOfChar}
    if b <> #0 then
    begin
      EmitRangeCPrim(b); // ###0.930
      if RangeIsCI then
        EmitRangeCPrim(InvertCase(b)); // ###0.930
    end
    else
    begin
      {$IFDEF UseAsserts}
      Assert(RangeLen > 0,
        'TRegExpr.ParseAtom(subroutine EmitRangeC): empty range');
      // impossible, but who knows..
      Assert(RangeChMin <= RangeChMax,
        'TRegExpr.ParseAtom(subroutine EmitRangeC): RangeChMin > RangeChMax');
      // impossible, but who knows..
      {$ENDIF}
      if RangeLen <= TinySetLen then
      begin // emit "tiny set"
        if regcode = @regdummy then
        begin
          regsize := RangePCodeIdx + TinySetLen; // RangeChMin/Max !!!
          Exit;
        end;
        regcode := RangePCodeBeg;
        for Ch := RangeChMin to RangeChMax do // ###0.930
          if Ch in RangeSet then
          begin
            regcode^ := Ch;
            Inc(regcode);
          end;
        // fill rest:
        while regcode < RangePCodeBeg + TinySetLen do
        begin
          regcode^ := RangeChMax;
          Inc(regcode);
        end;
        {$IFDEF DebugSynRegExpr}
        if regcode - programm > regsize then
          raise Exception.Create
            ('TRegExpr.ParseAtom.EmitRangeC TinySetLen buffer overrun');
        {$ENDIF}
      end
      else
      begin
        if regcode = @regdummy then
        begin
          regsize := RangePCodeIdx + SizeOf(TSetOfREChar);
          Exit;
        end;
        if (RangePCodeBeg - REOpSz - RENextOffSz)^ = OP_ANYBUTTINYSET then
          RangeSet := [#0 .. #255] - RangeSet;
        PREOp(RangePCodeBeg - REOpSz - RENextOffSz)^ := OP_ANYOFFULLSET;
        regcode := RangePCodeBeg;
        Move(RangeSet, regcode^, SizeOf(TSetOfREChar));
        Inc(regcode, SizeOf(TSetOfREChar));
        {$IFDEF DebugSynRegExpr}
        if regcode - programm > regsize then
          raise Exception.Create
            ('TRegExpr.ParseAtom.EmitRangeC non TinySetLen buffer overrun');
        {$ENDIF}
      end;
    end;
    {$ELSE}
    EmitC(b);
    {$ENDIF}
  end;

  procedure EmitSimpleRangeC(b: REChar);
  begin
    RangeBeg := b;
    EmitRangeC(b);
    CanBeRange := True;
  end;

  procedure EmitRangeStr(const s: RegExprString);
  var
    i: PtrInt;
  begin
    for i := 1 to length(s) do
      EmitRangeC(s[i]);
  end;

  function _IsMetaChar(ch: REChar): Boolean; {$IFDEF InlineFuncs}inline;{$ENDIF}
  begin
    case ch of
      'd', 'D',
      's', 'S',
      'w', 'W',
      'v', 'V',
      'h', 'H':
        Result := True
      else
        Result := False;
    end;
  end;

begin
  Result := nil;
  flags := 0;
  flagp := flag_Worst; // Tentatively.

  Inc(regparse);
  case (regparse - 1)^ of
    '^':
      if ((fCompModifiers and MaskModM) = 0) or
        ((fLineSeparators = '') and not fLinePairedSeparatorAssigned) then
        ret := EmitNode(OP_BOL)
      else
        ret := EmitNode(OP_BOLML);
    '$':
      if ((fCompModifiers and MaskModM) = 0) or
        ((fLineSeparators = '') and not fLinePairedSeparatorAssigned) then
        ret := EmitNode(OP_EOL)
      else
        ret := EmitNode(OP_EOLML);
    '.':
      if (fCompModifiers and MaskModS) <> 0 then
      begin
        ret := EmitNode(OP_ANY);
        flagp := flagp or flag_HasWidth or flag_Simple;
      end
      else
      begin // not /s, so emit [^:LineSeparators:]
        ret := EmitNode(OP_ANYML);
        flagp := flagp or flag_HasWidth; // not so simple ;)
        // ret := EmitRange (OP_ANYBUT);
        // EmitRangeStr (LineSeparators); //###0.941
        // EmitRangeStr (LinePairedSeparator); // !!! isn't correct if have to accept only paired
        // EmitRangeC (#0);
        // flagp := flagp or flag_HasWidth or flag_Simple;
      end;
    '[':
      begin
        if regparse^ = '^' then
        begin // Complement of range.
          if (fCompModifiers and MaskModI) <> 0 then
            ret := EmitRange(OP_ANYBUTCI)
          else
            ret := EmitRange(OP_ANYBUT);
          Inc(regparse);
        end
        else if (fCompModifiers and MaskModI) <> 0 then
          ret := EmitRange(OP_ANYOFCI)
        else
          ret := EmitRange(OP_ANYOF);

        CanBeRange := False;

        if (regparse^ = ']') then
        begin
          EmitSimpleRangeC(regparse^); // []-a] -> ']' .. 'a'
          Inc(regparse);
        end;

        while (regparse < fRegexEnd) and (regparse^ <> ']') do
        begin
          if (regparse^ = '-') and ((regparse + 1) < fRegexEnd) and
            ((regparse + 1)^ <> ']') and CanBeRange then
          begin
            Inc(regparse);
            RangeEnd := regparse^;
            if RangeEnd = EscChar then
            begin
              if _IsMetaChar((regparse + 1)^) then
              begin
                EmitRangeC('-'); // or treat as error ?!!
                Continue;
              end;
              Inc(regparse);
              RangeEnd := UnQuoteChar(regparse);
            end;

            // r.e.ranges extension for russian
            if ((fCompModifiers and MaskModR) <> 0) and
              (RangeBeg = RusRangeLoLow) and (RangeEnd = RusRangeLoHigh) then
            begin
              EmitRangeStr(RusRangeLo);
            end
            else if ((fCompModifiers and MaskModR) <> 0) and
              (RangeBeg = RusRangeHiLow) and (RangeEnd = RusRangeHiHigh) then
            begin
              EmitRangeStr(RusRangeHi);
            end
            else if ((fCompModifiers and MaskModR) <> 0) and
              (RangeBeg = RusRangeLoLow) and (RangeEnd = RusRangeHiHigh) then
            begin
              EmitRangeStr(RusRangeLo);
              EmitRangeStr(RusRangeHi);
            end
            else
            begin // standard r.e. handling
              if RangeBeg > RangeEnd then
              begin
                Error(reeInvalidRange);
                Exit;
              end;
              Inc(RangeBeg);
              EmitRangeC(RangeEnd); // prevent infinite OP_LOOP if RangeEnd=$ff
              while RangeBeg < RangeEnd do
              begin // ###0.929
                EmitRangeC(RangeBeg);
                Inc(RangeBeg);
              end;
            end;
            Inc(regparse);
          end
          else
          begin
            if regparse^ = EscChar then
            begin
              Inc(regparse);
              if regparse >= fRegexEnd then
              begin
                Error(reeParseAtomTrailingBackSlash);
                Exit;
              end;
              case regparse^ of // r.e.extensions
                'd':
                  EmitRangeStr('0123456789');
                'w':
                  {$IFDEF UseWordChars}
                  EmitRangeStr(WordChars);
                  {$ELSE}
                  EmitNode(OP_ANYLETTER);
                  {$ENDIF}
                's':
                  {$IFDEF UseSpaceChars}
                  EmitRangeStr(SpaceChars);
                  {$ELSE}
                  EmitNode(OP_ANYSPACE);
                  {$ENDIF}
                'v':
                  EmitRangeStr(RegExprLineSeparators);
                'h':
                  EmitRangeStr(RegExprHorzSeparators);
              else
                EmitSimpleRangeC(UnQuoteChar(regparse));
              end; { of case }
            end
            else
              EmitSimpleRangeC(regparse^);
            Inc(regparse);
          end;
        end; { of while }
        EmitRangeC(#0);
        if regparse^ <> ']' then
        begin
          Error(reeUnmatchedSqBrackets);
          Exit;
        end;
        Inc(regparse);
        flagp := flagp or flag_HasWidth or flag_Simple;
      end;
    '(':
      begin
        if regparse^ = '?' then
        begin
          // check for non-capturing group: (?:text)
          if (regparse + 1)^ = ':' then
          begin
            Inc(regparse, 2);
            ret := ParseReg(1, flags);
            if ret = nil then
            begin
              Result := nil;
              Exit;
            end;
            flagp := flagp or flags and (flag_HasWidth or flag_SpecStart);
          end
          else
            // check for extended Perl syntax : (?..)
            if (regparse + 1)^ = '#' then
            begin // (?#OP_COMMENT)
              Inc(regparse, 2); // find closing ')'
              while (regparse < fRegexEnd) and (regparse^ <> ')') do
                Inc(regparse);
              if regparse^ <> ')' then
              begin
                Error(reeUnclosedComment);
                Exit;
              end;
              Inc(regparse); // skip ')'
              ret := EmitNode(OP_COMMENT); // OP_COMMENT
            end
            else
            begin // modifiers ?
              Inc(regparse); // skip '?'
              begmodfs := regparse;
              while (regparse < fRegexEnd) and (regparse^ <> ')') do
                Inc(regparse);
              if (regparse^ <> ')') or
                not ParseModifiersStr(Copy(begmodfs, 1, (regparse - begmodfs)),
                fCompModifiers) then
              begin
                Error(reeUrecognizedModifier);
                Exit;
              end;
              Inc(regparse); // skip ')'
              ret := EmitNode(OP_COMMENT); // OP_COMMENT
              // Error (reeQPSBFollowsNothing);
              // Exit;
            end;
        end
        else
        begin
          // normal (capturing) group
          if fSecondPass then
          // must skip this block for one of passes, to not double groups count
            if FSubExprCount < NSUBEXP - 1 then
            begin
              Inc(FSubExprCount);
              FSubExprIndexes[FSubExprCount] := regnpar;
            end;
          ret := ParseReg(1, flags);
          if ret = nil then
          begin
            Result := nil;
            Exit;
          end;
          flagp := flagp or flags and (flag_HasWidth or flag_SpecStart);
        end;
      end;
    '|', ')':
      begin // Supposed to be caught earlier.
        Error(reeInternalUrp);
        Exit;
      end;
    '?', '+', '*':
      begin
        Error(reeQPSBFollowsNothing);
        Exit;
      end;
    EscChar:
      begin
        if regparse >= fRegexEnd then
        begin
          Error(reeTrailingBackSlash);
          Exit;
        end;
        case regparse^ of // r.e.extensions
          'b':
            ret := EmitNode(OP_BOUND); // ###0.943
          'B':
            ret := EmitNode(OP_NOTBOUND); // ###0.943
          'A':
            ret := EmitNode(OP_BOL); // ###0.941
          'Z':
            ret := EmitNode(OP_EOL); // ###0.941
          'd':
            begin // r.e.extension - OP_ANY digit ('0' .. '9')
              ret := EmitNode(OP_ANYDIGIT);
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'D':
            begin // r.e.extension - not digit ('0' .. '9')
              ret := EmitNode(OP_NOTDIGIT);
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          's':
            begin // r.e.extension - OP_ANY space char
              {$IFDEF UseSetOfChar}
              ret := EmitRange(OP_ANYOF);
              EmitRangeStr(SpaceChars);
              EmitRangeC(#0);
              {$ELSE}
              ret := EmitNode(OP_ANYSPACE);
              {$ENDIF}
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'S':
            begin // r.e.extension - not space char
              {$IFDEF UseSetOfChar}
              ret := EmitRange(OP_ANYBUT);
              EmitRangeStr(SpaceChars);
              EmitRangeC(#0);
              {$ELSE}
              ret := EmitNode(OP_NOTSPACE);
              {$ENDIF}
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'w':
            begin // r.e.extension - OP_ANY english char / digit / '_'
              {$IFDEF UseSetOfChar}
              ret := EmitRange(OP_ANYOF);
              EmitRangeStr(WordChars);
              EmitRangeC(#0);
              {$ELSE}
              ret := EmitNode(OP_ANYLETTER);
              {$ENDIF}
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'W':
            begin // r.e.extension - not english char / digit / '_'
              {$IFDEF UseSetOfChar}
              ret := EmitRange(OP_ANYBUT);
              EmitRangeStr(WordChars);
              EmitRangeC(#0);
              {$ELSE}
              ret := EmitNode(OP_NOTLETTER);
              {$ENDIF}
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'v':
            begin
              ret := EmitNode(OP_ANYVERTSEP);
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'V':
            begin
              ret := EmitNode(OP_NOTVERTSEP);
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'h':
            begin
              ret := EmitNode(OP_ANYHORZSEP);
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          'H':
            begin
              ret := EmitNode(OP_NOTHORZSEP);
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
          '1' .. '9':
            begin // ###0.936
              if (fCompModifiers and MaskModI) <> 0 then
                ret := EmitNode(OP_BSUBEXPCI)
              else
                ret := EmitNode(OP_BSUBEXP);
              EmitC(REChar(Ord(regparse^) - Ord('0')));
              flagp := flagp or flag_HasWidth or flag_Simple;
            end;
        else
          EmitExactly(UnQuoteChar(regparse));
        end; { of case }
        Inc(regparse);
      end;
  else
    begin
      Dec(regparse);
      if ((fCompModifiers and MaskModX) <> 0) and // check for eXtended syntax
        ((regparse^ = '#') or (
        {$IFDEF UniCode}
        StrScan(XIgnoredChars, regparse^) <> nil // ###0.947
        {$ELSE}
        regparse^ in XIgnoredChars
        {$ENDIF}
        )) then
      begin // ###0.941 \x
        if regparse^ = '#' then
        begin // Skip eXtended OP_COMMENT
          // find OP_COMMENT terminator (group of \n and/or \r)
          while (regparse < fRegexEnd) and (regparse^ <> #$d) and
            (regparse^ <> #$a) do
            Inc(regparse);
          while (regparse^ = #$d) or (regparse^ = #$a)
          // skip OP_COMMENT terminator
            do
            Inc(regparse);
          // attempt to support different type of line separators
        end
        else
        begin // Skip the blanks!
          while {$IFDEF UniCode}
                StrScan(XIgnoredChars, regparse^) <> nil // ###0.947
                {$ELSE}
                regparse^ in XIgnoredChars
                {$ENDIF}
            do
            Inc(regparse);
        end;
        ret := EmitNode(OP_COMMENT); // OP_COMMENT
      end
      else
      begin
        Len := FindInitLen(regparse, fMetaStart, fRegexEnd, fMetaEnd);
        if Len <= 0 then
          if regparse^ <> '{' then
          begin
            Error(reeRarseAtomInternalDisaster);
            Exit;
          end
          else
            Len := FindInitLen(regparse + 1, fMetaStart, fRegexEnd, fMetaEnd) +
              1; // bad {n,m} - compile as EXATLY
        ender := (regparse + Len)^;
        if (Len > 1) and ((ender = '*') or (ender = '+') or (ender = '?') or
          (ender = '{')) then
          Dec(Len); // OP_BACK off clear of ?+*{ operand.
        flagp := flagp or flag_HasWidth;
        if Len = 1 then
          flagp := flagp or flag_Simple;
        if (fCompModifiers and MaskModI) <> 0 then
          ret := EmitNode(OP_EXACTLYCI)
        else
          ret := EmitNode(OP_EXACTLY);
        while (Len > 0) and (((fCompModifiers and MaskModX) = 0) or
          (regparse^ <> '#')) do
        begin
          if ((fCompModifiers and MaskModX) = 0) or not( // ###0.941
            {$IFDEF UniCode}
            StrScan(XIgnoredChars, regparse^) <> nil // ###0.947
            {$ELSE}
            regparse^ in XIgnoredChars
            {$ENDIF} ) then
            EmitC(regparse^);
          Inc(regparse);
          Dec(Len);
        end;
        EmitC(#0);
      end; { of if not OP_COMMENT }
    end; { of case else }
  end; { of case }

  Result := ret;
end; { of function TRegExpr.ParseAtom
  -------------------------------------------------------------- }

function TRegExpr.GetCompilerErrorPos: PtrInt;
begin
  Result := 0;
  if (regexpbeg = nil) or (regparse = nil) then
    Exit; // not in compiling mode ?
  Result := regparse - regexpbeg;
end; { of function TRegExpr.GetCompilerErrorPos
  -------------------------------------------------------------- }

{ ============================================================= }
{ ===================== Matching section ====================== }
{ ============================================================= }

{$IFNDEF UseSetOfChar}
function TRegExpr.StrScanCI(s: PRegExprChar; Ch: REChar): PRegExprChar;
// ###0.928 - now method of TRegExpr
begin
  while (s^ <> #0) and (s^ <> Ch) and (s^ <> InvertCase(Ch)) do
    Inc(s);
  if s^ <> #0 then
    Result := s
  else
    Result := nil;
end; { of function TRegExpr.StrScanCI
  -------------------------------------------------------------- }
{$ENDIF}

function TRegExpr.regrepeat(p: PRegExprChar; AMax: PtrInt): PtrInt;
// repeatedly match something simple, report how many
var
  scan: PRegExprChar;
  opnd: PRegExprChar;
  TheMax: integer;
  { Ch, } InvCh: REChar; // ###0.931
  sestart, seend: PRegExprChar; // ###0.936
  ArrayIndex: integer;
begin
  Result := 0;
  scan := reginput;
  opnd := p + REOpSz + RENextOffSz; // OPERAND
  TheMax := fInputEnd - scan;
  if TheMax > AMax then
    TheMax := AMax;
  case PREOp(p)^ of
    OP_ANY:
      begin
        // note - OP_ANYML cannot be proceeded in regrepeat because can skip
        // more than one char at once
        Result := TheMax;
        Inc(scan, Result);
      end;
    OP_EXACTLY:
      begin // in opnd can be only ONE char !!!
        // Ch := opnd^; // store in register //###0.931
        while (Result < TheMax) and (opnd^ = scan^) do
        begin
          Inc(Result);
          Inc(scan);
        end;
      end;
    OP_EXACTLYCI:
      begin // in opnd can be only ONE char !!!
        // Ch := opnd^; // store in register //###0.931
        while (Result < TheMax) and (opnd^ = scan^) do
        begin // prevent unneeded InvertCase //###0.931
          Inc(Result);
          Inc(scan);
        end;
        if Result < TheMax then
        begin // ###0.931
          InvCh := InvertCase(opnd^); // store in register
          while (Result < TheMax) and ((opnd^ = scan^) or (InvCh = scan^)) do
          begin
            Inc(Result);
            Inc(scan);
          end;
        end;
      end;
    OP_BSUBEXP:
      begin // ###0.936
        ArrayIndex := FSubExprIndexes[Ord(opnd^)];
        if ArrayIndex < 0 then
          Exit;
        sestart := startp[ArrayIndex];
        if sestart = nil then
          Exit;
        seend := endp[ArrayIndex];
        if seend = nil then
          Exit;
        repeat
          opnd := sestart;
          while opnd < seend do
          begin
            if (scan >= fInputEnd) or (scan^ <> opnd^) then
              Exit;
            Inc(scan);
            Inc(opnd);
          end;
          Inc(Result);
          reginput := scan;
        until Result >= AMax;
      end;
    OP_BSUBEXPCI:
      begin // ###0.936
        ArrayIndex := FSubExprIndexes[Ord(opnd^)];
        if ArrayIndex < 0 then
          Exit;
        sestart := startp[ArrayIndex];
        if sestart = nil then
          Exit;
        seend := endp[ArrayIndex];
        if seend = nil then
          Exit;
        repeat
          opnd := sestart;
          while opnd < seend do
          begin
            if (scan >= fInputEnd) or
              ((scan^ <> opnd^) and (scan^ <> InvertCase(opnd^))) then
              Exit;
            Inc(scan);
            Inc(opnd);
          end;
          Inc(Result);
          reginput := scan;
        until Result >= AMax;
      end;
    OP_ANYDIGIT:
      while (Result < TheMax) and IsDigitChar(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_NOTDIGIT:
      while (Result < TheMax) and not IsDigitChar(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    {$IFNDEF UseSetOfChar} // ###0.929
    OP_ANYLETTER:
      while (Result < TheMax) and IsWordChar(scan^) do // ###0.940
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_NOTLETTER:
      while (Result < TheMax) and not IsWordChar(scan^) do // ###0.940
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_ANYSPACE:
      while (Result < TheMax) and IsSpaceChar(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_NOTSPACE:
      while (Result < TheMax) and not IsSpaceChar(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    {$ENDIF}
    OP_ANYVERTSEP:
      while (Result < TheMax) and IsLineSeparator(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_NOTVERTSEP:
      while (Result < TheMax) and not IsLineSeparator(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_ANYHORZSEP:
      while (Result < TheMax) and IsHorzSeparator(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_NOTHORZSEP:
      while (Result < TheMax) and not IsHorzSeparator(scan^) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_ANYOFTINYSET:
      begin
        while (Result < TheMax) and // !!!TinySet
          ((scan^ = opnd^) or (scan^ = (opnd + 1)^) or (scan^ = (opnd + 2)^)) do
        begin
          Inc(Result);
          Inc(scan);
        end;
      end;
    OP_ANYBUTTINYSET:
      begin
        while (Result < TheMax) and // !!!TinySet
          (scan^ <> opnd^) and (scan^ <> (opnd + 1)^) and
          (scan^ <> (opnd + 2)^) do
        begin
          Inc(Result);
          Inc(scan);
        end;
      end;
    {$IFDEF UseSetOfChar} // ###0.929
    OP_ANYOFFULLSET:
      begin
        while (Result < TheMax) and (scan^ in PSetOfREChar(opnd)^) do
        begin
          Inc(Result);
          Inc(scan);
        end;
      end;
    {$ELSE}
    OP_ANYOF:
      while (Result < TheMax) and (StrScan(opnd, scan^) <> nil) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_ANYBUT:
      while (Result < TheMax) and (StrScan(opnd, scan^) = nil) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_ANYOFCI:
      while (Result < TheMax) and (StrScanCI(opnd, scan^) <> nil) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    OP_ANYBUTCI:
      while (Result < TheMax) and (StrScanCI(opnd, scan^) = nil) do
      begin
        Inc(Result);
        Inc(scan);
      end;
    {$ENDIF}
  else
    begin // Oh dear. Called inappropriately.
      Result := 0; // Best compromise.
      Error(reeRegRepeatCalledInappropriately);
      Exit;
    end;
  end; { of case }
  reginput := scan;
end; { of function TRegExpr.regrepeat
  -------------------------------------------------------------- }

function TRegExpr.regnext(p: PRegExprChar): PRegExprChar;
// dig the "next" pointer out of a node
var
  offset: TRENextOff;
begin
  if p = @regdummy then
  begin
    Result := nil;
    Exit;
  end;
  offset := PRENextOff(AlignToPtr(p + REOpSz))^; // ###0.933 inlined NEXT
  if offset = 0 then
    Result := nil
  else
    Result := p + offset;
end; { of function TRegExpr.regnext
  -------------------------------------------------------------- }

function TRegExpr.MatchPrim(prog: PRegExprChar): boolean;
// recursively matching routine
// Conceptually the strategy is simple:  check to see whether the current
// node matches, call self recursively to see whether the rest matches,
// and then act accordingly. In practice we make some effort to avoid
// recursion, in particular by going through "ordinary" nodes (that don't
// need to know whether the rest of the match failed) by a OP_LOOP instead of
// by recursion.
Type
  TLoopStack = array [1 .. LoopStackMax] of integer;

var
  scan: PRegExprChar; // Current node.
  next: PRegExprChar; // Next node.
  Len: PtrInt;
  opnd: PRegExprChar;
  no: PtrInt;
  save: PRegExprChar;
  nextch: REChar;
  BracesMin, Bracesmax: PtrInt;
  // we use integer instead of TREBracesArg for better support */+
  {$IFDEF ComplexBraces}
  SavedLoopStack: TLoopStack; // :(( very bad for recursion
  SavedLoopStackIdx: integer; // ###0.925
  {$ENDIF}
begin
  Result := False;
  scan := prog;
  FillChar(SavedLoopStack[1], length(SavedLoopStack), 0);
  while scan <> nil do
  begin
    Len := PRENextOff(AlignToPtr(scan + 1))^; // ###0.932 inlined regnext
    if Len = 0 then
      next := nil
    else
      next := scan + Len;

    case scan^ of
      OP_NOTBOUND, // ###0.943 //!!! think about UseSetOfChar !!!
      OP_BOUND:
        if (scan^ = OP_BOUND)
          xor (((reginput = fInputStart) or not IsWordChar((reginput - 1)^)) and
          (reginput < fInputEnd) and IsWordChar(reginput^) or
          (reginput <> fInputStart) and IsWordChar((reginput - 1)^) and
          ((reginput = fInputEnd) or not IsWordChar(reginput^))) then
          Exit;

      OP_BOL:
        if reginput <> fInputStart then
          Exit;
      OP_EOL:
        if reginput < fInputEnd then
          Exit;
      OP_BOLML:
        if reginput > fInputStart then
        begin
          nextch := (reginput - 1)^;
          if (nextch <> fLinePairedSeparatorTail) or
            ((reginput - 1) <= fInputStart) or
            ((reginput - 2)^ <> fLinePairedSeparatorHead) then
          begin
            if (nextch = fLinePairedSeparatorHead) and
              (reginput^ = fLinePairedSeparatorTail) then
              Exit; // don't stop between paired separator
            if
              {$IFNDEF UniCode}
              not (nextch in fLineSeparatorsSet)
              {$ELSE}
              (Pos(nextch, fLineSeparators) <= 0)
              {$ENDIF}
            then
              Exit;
          end;
        end;
      OP_EOLML:
        if reginput < fInputEnd then
        begin
          nextch := reginput^;
          if (nextch <> fLinePairedSeparatorHead) or
            ((reginput + 1)^ <> fLinePairedSeparatorTail) then
          begin
            if (nextch = fLinePairedSeparatorTail) and (reginput > fInputStart)
              and ((reginput - 1)^ = fLinePairedSeparatorHead) then
              Exit; // don't stop between paired separator
            if
              {$IFNDEF UniCode}
              not (nextch in fLineSeparatorsSet)
              {$ELSE}
              (Pos(nextch, fLineSeparators) <= 0)
              {$ENDIF}
            then
              Exit;
          end;
        end;
      OP_ANY:
        begin
          if reginput = fInputEnd then
            Exit;
          Inc(reginput);
        end;
      OP_ANYML:
        begin // ###0.941
          if (reginput = fInputEnd) or
            ((reginput^ = fLinePairedSeparatorHead) and
            ((reginput + 1)^ = fLinePairedSeparatorTail)) or
            {$IFNDEF UniCode}
            (reginput^ in fLineSeparatorsSet)
            {$ELSE}
            (Pos(reginput^, fLineSeparators) > 0)
            {$ENDIF}
          then
            Exit;
          Inc(reginput);
        end;
      OP_ANYDIGIT:
        begin
          if (reginput = fInputEnd) or not IsDigitChar(reginput^) then
            Exit;
          Inc(reginput);
        end;
      OP_NOTDIGIT:
        begin
          if (reginput = fInputEnd) or IsDigitChar(reginput^) then
            Exit;
          Inc(reginput);
        end;
      {$IFNDEF UseSetOfChar} // ###0.929
      OP_ANYLETTER:
        begin
          if (reginput = fInputEnd) or not IsWordChar(reginput^) // ###0.943
          then
            Exit;
          Inc(reginput);
        end;
      OP_NOTLETTER:
        begin
          if (reginput = fInputEnd) or IsWordChar(reginput^) // ###0.943
          then
            Exit;
          Inc(reginput);
        end;
      OP_ANYSPACE:
        begin
          if (reginput = fInputEnd) or not IsSpaceChar(reginput^) // ###0.943
          then
            Exit;
          Inc(reginput);
        end;
      OP_NOTSPACE:
        begin
          if (reginput = fInputEnd) or IsSpaceChar(reginput^) // ###0.943
          then
            Exit;
          Inc(reginput);
        end;
      {$ENDIF}
      OP_ANYVERTSEP:
        begin
          if (reginput = fInputEnd) or not IsLineSeparator(reginput^) then
            Exit;
          Inc(reginput);
        end;
      OP_NOTVERTSEP:
        begin
          if (reginput = fInputEnd) or IsLineSeparator(reginput^) then
            Exit;
          Inc(reginput);
        end;
      OP_ANYHORZSEP:
        begin
          if (reginput = fInputEnd) or not IsHorzSeparator(reginput^) then
            Exit;
          Inc(reginput);
        end;
      OP_NOTHORZSEP:
        begin
          if (reginput = fInputEnd) or IsHorzSeparator(reginput^) then
            Exit;
          Inc(reginput);
        end;
      OP_EXACTLYCI:
        begin
          opnd := scan + REOpSz + RENextOffSz; // OPERAND
          // Inline the first character, for speed.
          if (opnd^ <> reginput^) and (InvertCase(opnd^) <> reginput^) then
            Exit;
          Len := strlen(opnd);
          // ###0.929 begin
          no := Len;
          save := reginput;
          while no > 1 do
          begin
            Inc(save);
            Inc(opnd);
            if (opnd^ <> save^) and (InvertCase(opnd^) <> save^) then
              Exit;
            Dec(no);
          end;
          // ###0.929 end
          Inc(reginput, Len);
        end;
      OP_EXACTLY:
        begin
          opnd := scan + REOpSz + RENextOffSz; // OPERAND
          // Inline the first character, for speed.
          if opnd^ <> reginput^ then
            Exit;
          Len := strlen(opnd);
          // ###0.929 begin
          no := Len;
          save := reginput;
          while no > 1 do
          begin
            Inc(save);
            Inc(opnd);
            if opnd^ <> save^ then
              Exit;
            Dec(no);
          end;
          // ###0.929 end
          Inc(reginput, Len);
        end;
      OP_BSUBEXP:
        begin // ###0.936
          no := Ord((scan + REOpSz + RENextOffSz)^);
          no := FSubExprIndexes[no];
          if no < 0 then
            Exit;
          if startp[no] = nil then
            Exit;
          if endp[no] = nil then
            Exit;
          save := reginput;
          opnd := startp[no];
          while opnd < endp[no] do
          begin
            if (save >= fInputEnd) or (save^ <> opnd^) then
              Exit;
            Inc(save);
            Inc(opnd);
          end;
          reginput := save;
        end;
      OP_BSUBEXPCI:
        begin // ###0.936
          no := Ord((scan + REOpSz + RENextOffSz)^);
          no := FSubExprIndexes[no];
          if no < 0 then
            Exit;
          if startp[no] = nil then
            Exit;
          if endp[no] = nil then
            Exit;
          save := reginput;
          opnd := startp[no];
          while opnd < endp[no] do
          begin
            if (save >= fInputEnd) or
              ((save^ <> opnd^) and (save^ <> InvertCase(opnd^))) then
              Exit;
            Inc(save);
            Inc(opnd);
          end;
          reginput := save;
        end;
      OP_ANYOFTINYSET:
        begin
          if (reginput = fInputEnd) or // !!!TinySet
            ((reginput^ <> (scan + REOpSz + RENextOffSz)^) and
            (reginput^ <> (scan + REOpSz + RENextOffSz + 1)^) and
            (reginput^ <> (scan + REOpSz + RENextOffSz + 2)^)) then
            Exit;
          Inc(reginput);
        end;
      OP_ANYBUTTINYSET:
        begin
          if (reginput = fInputEnd) or // !!!TinySet
            (reginput^ = (scan + REOpSz + RENextOffSz)^) or
            (reginput^ = (scan + REOpSz + RENextOffSz + 1)^) or
            (reginput^ = (scan + REOpSz + RENextOffSz + 2)^) then
            Exit;
          Inc(reginput);
        end;
      {$IFDEF UseSetOfChar} // ###0.929
      OP_ANYOFFULLSET:
        begin
          if (reginput = fInputEnd) or
            not(reginput^ in PSetOfREChar(scan + REOpSz + RENextOffSz)^) then
            Exit;
          Inc(reginput);
        end;
      {$ELSE}
      OP_ANYOF:
        begin
          if (reginput = fInputEnd) or
            (StrScan(scan + REOpSz + RENextOffSz, reginput^) = nil) then
            Exit;
          Inc(reginput);
        end;
      OP_ANYBUT:
        begin
          if (reginput = fInputEnd) or
            (StrScan(scan + REOpSz + RENextOffSz, reginput^) <> nil) then
            Exit;
          Inc(reginput);
        end;
      OP_ANYOFCI:
        begin
          if (reginput = fInputEnd) or
            (StrScanCI(scan + REOpSz + RENextOffSz, reginput^) = nil) then
            Exit;
          Inc(reginput);
        end;
      OP_ANYBUTCI:
        begin
          if (reginput = fInputEnd) or
            (StrScanCI(scan + REOpSz + RENextOffSz, reginput^) <> nil) then
            Exit;
          Inc(reginput);
        end;
      {$ENDIF}
      OP_NOTHING:
        ;
      OP_COMMENT:
        ;
      OP_BACK:
        ;
      Succ(OP_OPEN) .. TREOp(Ord(OP_OPEN) + NSUBEXP - 1):
        begin // ###0.929
          no := Ord(scan^) - Ord(OP_OPEN);
          // save := reginput;
          save := startp[no]; // ###0.936
          startp[no] := reginput; // ###0.936
          Result := MatchPrim(next);
          if not Result // ###0.936
          then
            startp[no] := save;
          // if Result and (startp [no] = nil)
          // then startp [no] := save;
          // Don't set startp if some later invocation of the same
          // parentheses already has.
          Exit;
        end;
      Succ(OP_CLOSE) .. TREOp(Ord(OP_CLOSE) + NSUBEXP - 1):
        begin // ###0.929
          no := Ord(scan^) - Ord(OP_CLOSE);
          // save := reginput;
          save := endp[no]; // ###0.936
          endp[no] := reginput; // ###0.936
          Result := MatchPrim(next);
          if not Result // ###0.936
          then
            endp[no] := save;
          // if Result and (endp [no] = nil)
          // then endp [no] := save;
          // Don't set endp if some later invocation of the same
          // parentheses already has.
          Exit;
        end;
      OP_BRANCH:
        begin
          if (next^ <> OP_BRANCH) // No choice.
          then
            next := scan + REOpSz + RENextOffSz // Avoid recursion
          else
          begin
            repeat
              save := reginput;
              Result := MatchPrim(scan + REOpSz + RENextOffSz);
              if Result then
                Exit;
              reginput := save;
              scan := regnext(scan);
            until (scan = nil) or (scan^ <> OP_BRANCH);
            Exit;
          end;
        end;
      {$IFDEF ComplexBraces}
      OP_LOOPENTRY:
        begin // ###0.925
          no := LoopStackIdx;
          Inc(LoopStackIdx);
          if LoopStackIdx > LoopStackMax then
          begin
            Error(reeLoopStackExceeded);
            Exit;
          end;
          save := reginput;
          LoopStack[LoopStackIdx] := 0; // init OP_LOOP counter
          Result := MatchPrim(next); // execute OP_LOOP
          LoopStackIdx := no; // cleanup
          if Result then
            Exit;
          reginput := save;
          Exit;
        end;
      OP_LOOP, OP_LOOPNG:
        begin // ###0.940
          if LoopStackIdx <= 0 then
          begin
            Error(reeLoopWithoutEntry);
            Exit;
          end;
          opnd := scan + PRENextOff(AlignToPtr(scan + REOpSz + RENextOffSz + 2 *
            REBracesArgSz))^;
          BracesMin := PREBracesArg(AlignToInt(scan + REOpSz + RENextOffSz))^;
          Bracesmax :=
            PREBracesArg(AlignToPtr(scan + REOpSz + RENextOffSz +
            REBracesArgSz))^;
          save := reginput;
          if LoopStack[LoopStackIdx] >= BracesMin then
          begin // Min alredy matched - we can work
            if scan^ = OP_LOOP then
            begin
              // greedy way - first try to max deep of greed ;)
              if LoopStack[LoopStackIdx] < Bracesmax then
              begin
                Inc(LoopStack[LoopStackIdx]);
                no := LoopStackIdx;
                Result := MatchPrim(opnd);
                LoopStackIdx := no;
                if Result then
                  Exit;
                reginput := save;
              end;
              Dec(LoopStackIdx); // Fail. May be we are too greedy? ;)
              Result := MatchPrim(next);
              if not Result then
                reginput := save;
              Exit;
            end
            else
            begin
              // non-greedy - try just now
              Result := MatchPrim(next);
              if Result then
                Exit
              else
                reginput := save; // failed - move next and try again
              if LoopStack[LoopStackIdx] < Bracesmax then
              begin
                Inc(LoopStack[LoopStackIdx]);
                no := LoopStackIdx;
                Result := MatchPrim(opnd);
                LoopStackIdx := no;
                if Result then
                  Exit;
                reginput := save;
              end;
              Dec(LoopStackIdx); // Failed - OP_BACK up
              Exit;
            end
          end
          else
          begin // first match a min_cnt times
            Inc(LoopStack[LoopStackIdx]);
            no := LoopStackIdx;
            Result := MatchPrim(opnd);
            LoopStackIdx := no;
            if Result then
              Exit;
            Dec(LoopStack[LoopStackIdx]);
            reginput := save;
            Exit;
          end;
        end;
      {$ENDIF}
      OP_STAR, OP_PLUS, OP_BRACES, OP_STARNG, OP_PLUSNG, OP_BRACESNG:
        begin
          // Lookahead to avoid useless match attempts when we know
          // what character comes next.
          nextch := #0;
          if next^ = OP_EXACTLY then
            nextch := (next + REOpSz + RENextOffSz)^;
          Bracesmax := MaxInt; // infinite OP_LOOP for * and + //###0.92
          if (scan^ = OP_STAR) or (scan^ = OP_STARNG) then
            BracesMin := 0 // OP_STAR
          else if (scan^ = OP_PLUS) or (scan^ = OP_PLUSNG) then
            BracesMin := 1 // OP_PLUS
          else
          begin // OP_BRACES
            BracesMin := PREBracesArg(AlignToPtr(scan + REOpSz + RENextOffSz))^;
            Bracesmax :=
              PREBracesArg(AlignToPtr(scan + REOpSz + RENextOffSz +
              REBracesArgSz))^;
          end;
          save := reginput;
          opnd := scan + REOpSz + RENextOffSz;
          if (scan^ = OP_BRACES) or (scan^ = OP_BRACESNG) then
            Inc(opnd, 2 * REBracesArgSz);

          if (scan^ = OP_PLUSNG) or (scan^ = OP_STARNG) or (scan^ = OP_BRACESNG) then
          begin
            // non-greedy mode
            Bracesmax := regrepeat(opnd, Bracesmax);
            // don't repeat more than BracesMax
            // Now we know real Max limit to move forward (for recursion 'back up')
            // In some cases it can be faster to check only Min positions first,
            // but after that we have to check every position separtely instead
            // of fast scannig in OP_LOOP.
            no := BracesMin;
            while no <= Bracesmax do
            begin
              reginput := save + no;
              // If it could work, try it.
              if (nextch = #0) or (reginput^ = nextch) then
              begin
                {$IFDEF ComplexBraces}
                System.Move(LoopStack, SavedLoopStack, SizeOf(LoopStack));
                // ###0.925
                SavedLoopStackIdx := LoopStackIdx;
                {$ENDIF}
                if MatchPrim(next) then
                begin
                  Result := True;
                  Exit;
                end;
                {$IFDEF ComplexBraces}
                System.Move(SavedLoopStack, LoopStack, SizeOf(LoopStack));
                LoopStackIdx := SavedLoopStackIdx;
                {$ENDIF}
              end;
              Inc(no); // Couldn't or didn't - move forward.
            end; { of while }
            Exit;
          end
          else
          begin // greedy mode
            no := regrepeat(opnd, Bracesmax); // don't repeat more than max_cnt
            while no >= BracesMin do
            begin
              // If it could work, try it.
              if (nextch = #0) or (reginput^ = nextch) then
              begin
                {$IFDEF ComplexBraces}
                System.Move(LoopStack, SavedLoopStack, SizeOf(LoopStack));
                // ###0.925
                SavedLoopStackIdx := LoopStackIdx;
                {$ENDIF}
                if MatchPrim(next) then
                begin
                  Result := True;
                  Exit;
                end;
                {$IFDEF ComplexBraces}
                System.Move(SavedLoopStack, LoopStack, SizeOf(LoopStack));
                LoopStackIdx := SavedLoopStackIdx;
                {$ENDIF}
              end;
              Dec(no); // Couldn't or didn't - OP_BACK up.
              reginput := save + no;
            end; { of while }
            Exit;
          end;
        end;
      OP_EEND:
        begin
          Result := True; // Success!
          Exit;
        end;
    else
      begin
        Error(reeMatchPrimMemoryCorruption);
        Exit;
      end;
    end; { of case scan^ }
    scan := next;
  end; { of while scan <> nil }

  // We get here only if there's trouble -- normally "case EEND" is the
  // terminating point.
  Error(reeMatchPrimCorruptedPointers);
end; { of function TRegExpr.MatchPrim
  -------------------------------------------------------------- }

{$IFDEF UseFirstCharSet}
// ###0.929
procedure TRegExpr.FillFirstCharSet(prog: PRegExprChar);
var
  scan: PRegExprChar; // Current node.
  next: PRegExprChar; // Next node.
  opnd: PRegExprChar;
  min_cnt: integer;
begin
  scan := prog;
  while scan <> nil do
  begin
    next := regnext(scan);
    case PREOp(scan)^ of
      OP_BSUBEXP, OP_BSUBEXPCI:
        begin // ###0.938
          FirstCharSet := [#0 .. #255]; // :((( we cannot
          // optimize r.e. if it starts with OP_BACK reference
          Exit;
        end;
      OP_BOL, OP_BOLML:
        ; // Exit; //###0.937
      OP_EOL, OP_EOLML:
        begin // ###0.948 was empty in 0.947, was Exit in 0.937
          Include(FirstCharSet, #0);
          if ModifierM then
          begin
            opnd := PRegExprChar(LineSeparators);
            while opnd^ <> #0 do
            begin
              Include(FirstCharSet, opnd^);
              Inc(opnd);
            end;
          end;
          Exit;
        end;
      OP_BOUND, OP_NOTBOUND:
        ; // ###0.943 ?!!
      OP_ANY, OP_ANYML:
        begin // we can better define OP_ANYML !!!
          FirstCharSet := [#0 .. #255]; // ###0.930
          Exit;
        end;
      OP_ANYDIGIT:
        begin
          FirstCharSet := FirstCharSet + ['0' .. '9'];
          Exit;
        end;
      OP_NOTDIGIT:
        begin
          FirstCharSet := FirstCharSet + ([#0 .. #255] - ['0' .. '9']);
          // ###0.948 FirstCharSet was forgotten
          Exit;
        end;
      OP_ANYVERTSEP:
        begin
          FirstCharSet := FirstCharSet + [#$d, #$a, #$b, #$c];
          Exit;
        end;
      OP_NOTVERTSEP:
        begin
          FirstCharSet := FirstCharSet + ([#0 .. #255] - [#$d, #$a, #$b, #$c]);
          Exit;
        end;
      OP_ANYHORZSEP:
        begin
          FirstCharSet := FirstCharSet + [#9, #$20, #$A0];
          Exit;
        end;
      OP_NOTHORZSEP:
        begin
          FirstCharSet := FirstCharSet + ([#0 .. #255] - [#9, #$20, #$A0]);
          Exit;
        end;
      OP_EXACTLYCI:
        begin
          Include(FirstCharSet, (scan + REOpSz + RENextOffSz)^);
          Include(FirstCharSet, InvertCase((scan + REOpSz + RENextOffSz)^));
          Exit;
        end;
      OP_EXACTLY:
        begin
          Include(FirstCharSet, (scan + REOpSz + RENextOffSz)^);
          Exit;
        end;
      OP_ANYOFFULLSET:
        begin
          FirstCharSet := FirstCharSet +
            PSetOfREChar(scan + REOpSz + RENextOffSz)^;
          Exit;
        end;
      OP_ANYOFTINYSET:
        begin
          // !!!TinySet
          Include(FirstCharSet, (scan + REOpSz + RENextOffSz)^);
          Include(FirstCharSet, (scan + REOpSz + RENextOffSz + 1)^);
          Include(FirstCharSet, (scan + REOpSz + RENextOffSz + 2)^);
          // ...                                                      // up to TinySetLen
          Exit;
        end;
      OP_ANYBUTTINYSET:
        begin
          // !!!TinySet
          FirstCharSet := FirstCharSet + ([#0 .. #255] - [
            // ###0.948 FirstCharSet was forgotten
            (scan + REOpSz + RENextOffSz)^, (scan + REOpSz + RENextOffSz + 1)^,
            (scan + REOpSz + RENextOffSz + 2)^]);
          // ...                                                      // up to TinySetLen
          Exit;
        end;
      OP_NOTHING:
        ;
      OP_COMMENT:
        ;
      OP_BACK:
        ;
      Succ(OP_OPEN) .. TREOp(Ord(OP_OPEN) + NSUBEXP - 1):
        begin // ###0.929
          FillFirstCharSet(next);
          Exit;
        end;
      Succ(OP_CLOSE) .. TREOp(Ord(OP_CLOSE) + NSUBEXP - 1):
        begin // ###0.929
          FillFirstCharSet(next);
          Exit;
        end;
      OP_BRANCH:
        begin
          if (PREOp(next)^ <> OP_BRANCH) // No choice.
          then
            next := scan + REOpSz + RENextOffSz // Avoid recursion.
          else
          begin
            repeat
              FillFirstCharSet(scan + REOpSz + RENextOffSz);
              scan := regnext(scan);
            until (scan = nil) or (PREOp(scan)^ <> OP_BRANCH);
            Exit;
          end;
        end;
      {$IFDEF ComplexBraces}
      OP_LOOPENTRY:
        begin // ###0.925
          // LoopStack [LoopStackIdx] := 0; //###0.940 line removed
          FillFirstCharSet(next); // execute OP_LOOP
          Exit;
        end;
      OP_LOOP, OP_LOOPNG:
        begin // ###0.940
          opnd := scan + PRENextOff(AlignToPtr(scan + REOpSz + RENextOffSz +
            REBracesArgSz * 2))^;
          min_cnt := PREBracesArg(AlignToPtr(scan + REOpSz + RENextOffSz))^;
          FillFirstCharSet(opnd);
          if min_cnt = 0 then
            FillFirstCharSet(next);
          Exit;
        end;
      {$ENDIF}
      OP_STAR, OP_STARNG: // ###0.940
        FillFirstCharSet(scan + REOpSz + RENextOffSz);
      OP_PLUS, OP_PLUSNG:
        begin // ###0.940
          FillFirstCharSet(scan + REOpSz + RENextOffSz);
          Exit;
        end;
      OP_BRACES, OP_BRACESNG:
        begin // ###0.940
          opnd := scan + REOpSz + RENextOffSz + REBracesArgSz * 2;
          min_cnt := PREBracesArg(AlignToPtr(scan + REOpSz + RENextOffSz))^;
          // OP_BRACES
          FillFirstCharSet(opnd);
          if min_cnt > 0 then
            Exit;
        end;
      OP_EEND:
        begin
          FirstCharSet := [#0 .. #255]; // ###0.948
          Exit;
        end;
    else
      begin
        Error(reeMatchPrimMemoryCorruption);
        Exit;
      end;
    end; { of case scan^ }
    scan := next;
  end; { of while scan <> nil }
end; { of procedure FillFirstCharSet
  -------------------------------------------------------------- }
{$ENDIF}

function TRegExpr.Exec(const AInputString: RegExprString): boolean;
begin
  InputString := AInputString;
  Result := ExecPrim(1);
end; { of function TRegExpr.Exec
  -------------------------------------------------------------- }

{$IFDEF OverMeth}
function TRegExpr.Exec: boolean;
begin
  Result := ExecPrim(1);
end; { of function TRegExpr.Exec
  -------------------------------------------------------------- }

function TRegExpr.Exec(AOffset: PtrInt): boolean;
begin
  Result := ExecPrim(AOffset);
end; { of function TRegExpr.Exec
  -------------------------------------------------------------- }
{$ENDIF}

function TRegExpr.ExecPos(AOffset: PtrInt
  {$IFDEF DefParam} = 1{$ENDIF}): boolean;
begin
  Result := ExecPrim(AOffset);
end; { of function TRegExpr.ExecPos
  -------------------------------------------------------------- }

function TRegExpr.ExecPrim(AOffset: PtrInt): boolean;
  procedure ClearMatchs;
  // Clears matchs array
  var
    i: integer;
  begin
    for i := 0 to NSUBEXP - 1 do
    begin
      startp[i] := nil;
      endp[i] := nil;
    end;
  end; { of procedure ClearMatchs;
  .............................................................. }
  function RegMatch(str: PRegExprChar): boolean;
  // try match at specific point
  begin
    // ###0.949 removed clearing of start\endp
    reginput := str;
    Result := MatchPrim(programm + REOpSz);
    if Result then
    begin
      startp[0] := str;
      endp[0] := reginput;
    end;
  end; { of function RegMatch
  .............................................................. }

var
  s: PRegExprChar;
  StartPtr: PRegExprChar;
begin
  Result := False; // Be paranoid...

  ClearMatchs; // ###0.949
  // ensure that Match cleared either if optimization tricks or some error
  // will lead to leaving ExecPrim without actual search. That is
  // importent for ExecNext logic and so on.

  if not IsProgrammOk // ###0.929
  then
    Exit;

  // Check InputString presence
  if fInputString = '' then
  begin
    Error(reeNoInputStringSpecified);
    Exit;
  end;

  // Check that the start position is not negative
  if AOffset < 1 then
  begin
    Error(reeOffsetMustBeGreaterThen0);
    Exit;
  end;
  // Check that the start position is not longer than the line
  // If so then exit with OP_NOTHING found
  if AOffset > (length(fInputString) + 1)
  // for matching empty string after last char.
  then
    Exit;

  StartPtr := fInputStart + AOffset - 1;

  // If there is a "must appear" string, look for it.
  if regmust <> nil then
  begin
    s := StartPtr;
    repeat
      s := StrScan(s, regmust[0]);
      if s <> nil then
      begin
        if StrLComp(s, regmust, regmlen) = 0 then
          Break; // Found it.
        Inc(s);
      end;
    until s = nil;
    if s = nil // Not present.
    then
      Exit;
  end;

  {$IFDEF ComplexBraces}
  // no loops started
  LoopStackIdx := 0; // ###0.925
  {$ENDIF}
  // Simplest case:  anchored match need be tried only once.
  if reganch <> #0 then
  begin
    Result := RegMatch(StartPtr);
    Exit;
  end;

  // Messy cases:  unanchored match.
  s := StartPtr;
  if regstart <> #0 then // We know what char it must start with.
    repeat
      s := StrScan(s, regstart);
      if s <> nil then
      begin
        Result := RegMatch(s);
        if Result then
          Exit
        else
          ClearMatchs; // ###0.949
        Inc(s);
      end;
    until s = nil
  else
  begin // We don't - general case.
    repeat // ###0.948
      {$IFDEF UseFirstCharSet}
      if s^ in FirstCharSet then
        Result := RegMatch(s);
      {$ELSE}
      Result := RegMatch(s);
      {$ENDIF}
      if Result or (s = fInputEnd)
      // Exit on a match or after testing the end-of-string.
      then
        Exit
      else
        ClearMatchs; // ###0.949
      Inc(s);
    until False;
    (* optimized and fixed by Martin Fuller - empty strings
      were not allowed to pass through in UseFirstCharSet mode
      {$IFDEF UseFirstCharSet} //###0.929
      while s < fInputEnd do
      begin
        if s^ in FirstCharSet then
          Result := RegMatch (s);
        if Result
          then exit;
        Inc(s);
      end;
      {$ELSE}
      repeat
        Result := RegMatch (s);
        if Result
          then exit;
        Inc(s);
      until s = fInputEnd;
      {$ENDIF}
    *)
  end;
  // Failure
end; { of function TRegExpr.ExecPrim
  -------------------------------------------------------------- }

function TRegExpr.ExecNext: boolean;
var
  offset: PtrInt;
begin
  Result := False;
  if not Assigned(startp[0]) or not Assigned(endp[0]) then
  begin
    Error(reeExecNextWithoutExec);
    Exit;
  end;
  // Offset := MatchPos [0] + MatchLen [0];
  // if MatchLen [0] = 0
  offset := endp[0] - fInputStart + 1; // ###0.929
  if endp[0] = startp[0] // ###0.929
  then
    Inc(offset); // prevent infinite looping if empty string match r.e.
  Result := ExecPrim(offset);
end; { of function TRegExpr.ExecNext
  -------------------------------------------------------------- }

procedure TRegExpr.SetInputString(const AInputString: RegExprString);
var
  i: PtrInt;
begin
  // clear Match* - before next Exec* call it's undefined
  for i := 0 to NSUBEXP - 1 do
  begin
    startp[i] := nil;
    endp[i] := nil;
  end;

  fInputString := AInputString;
  UniqueString(fInputString);

  fInputStart := PRegExprChar(fInputString);
  fInputEnd := fInputStart + length(fInputString);
end; { of procedure TRegExpr.SetInputString
  -------------------------------------------------------------- }

procedure TRegExpr.SetLineSeparators(const AStr: RegExprString);
begin
  if AStr <> fLineSeparators then
  begin
    fLineSeparators := AStr;
    InvalidateProgramm;
  end;
end; { of procedure TRegExpr.SetLineSeparators
  -------------------------------------------------------------- }

procedure TRegExpr.SetLinePairedSeparator(const AStr: RegExprString);
begin
  if length(AStr) = 2 then
  begin
    if AStr[1] = AStr[2] then
    begin
      // it's impossible for our 'one-point' checking to support
      // two chars separator for identical chars
      Error(reeBadLinePairedSeparator);
      Exit;
    end;
    if not fLinePairedSeparatorAssigned or (AStr[1] <> fLinePairedSeparatorHead)
      or (AStr[2] <> fLinePairedSeparatorTail) then
    begin
      fLinePairedSeparatorAssigned := True;
      fLinePairedSeparatorHead := AStr[1];
      fLinePairedSeparatorTail := AStr[2];
      InvalidateProgramm;
    end;
  end
  else if length(AStr) = 0 then
  begin
    if fLinePairedSeparatorAssigned then
    begin
      fLinePairedSeparatorAssigned := False;
      InvalidateProgramm;
    end;
  end
  else
    Error(reeBadLinePairedSeparator);
end; { of procedure TRegExpr.SetLinePairedSeparator
  -------------------------------------------------------------- }

function TRegExpr.GetLinePairedSeparator: RegExprString;
begin
  if fLinePairedSeparatorAssigned then
  begin
    {$IFDEF UniCode}
    // Here is some UniCode 'magic'
    // If You do know better decision to concatenate
    // two WideChars, please, let me know!
    Result := fLinePairedSeparatorHead; // ###0.947
    Result := Result + fLinePairedSeparatorTail;
    {$ELSE}
    Result := fLinePairedSeparatorHead + fLinePairedSeparatorTail;
    {$ENDIF}
  end
  else
    Result := '';
end; { of function TRegExpr.GetLinePairedSeparator
  -------------------------------------------------------------- }

function TRegExpr.Substitute(const ATemplate: RegExprString): RegExprString;
// perform substitutions after a regexp match
// completely rewritten in 0.929
type
  TSubstMode = (smodeNormal, smodeOneUpper, smodeOneLower, smodeAllUpper,
    smodeAllLower);
var
  TemplateLen: PtrInt;
  TemplateBeg, TemplateEnd: PRegExprChar;
  p, p0, p1, ResultPtr: PRegExprChar;
  ResultLen: PtrInt;
  n: PtrInt;
  Ch: REChar;
  Mode: TSubstMode;
  QuotedChar: REChar;

  function ParseVarName(var APtr: PRegExprChar): PtrInt;
  // extract name of variable (digits, may be enclosed with
  // curly OP_BRACES) from APtr^, uses TemplateEnd !!!
  var
    p: PRegExprChar;
    Delimited: boolean;
  begin
    Result := 0;
    p := APtr;
    Delimited := (p < TemplateEnd) and (p^ = '{');
    if Delimited then
      Inc(p); // skip left curly brace
    if (p < TemplateEnd) and (p^ = '&') then
      Inc(p) // this is '$&' or '${&}'
    else
      while (p < TemplateEnd) and IsDigitChar(p^) do
      begin
        Result := Result * 10 + (Ord(p^) - Ord('0')); // ###0.939
        Inc(p);
      end;
    if Delimited then
      if (p < TemplateEnd) and (p^ = '}') then
        Inc(p) // skip right curly brace
      else
        p := APtr; // isn't properly terminated
    if p = APtr then
      Result := -1; // no valid digits found or no right curly brace
    APtr := p;
  end;

begin
  // Check programm and input string
  if not IsProgrammOk then
    Exit;
  if fInputString = '' then
  begin
    Error(reeNoInputStringSpecified);
    Exit;
  end;
  // Prepare for working
  TemplateLen := length(ATemplate);
  if TemplateLen = 0 then
  begin // prevent nil pointers
    Result := '';
    Exit;
  end;
  TemplateBeg := Pointer(ATemplate);
  TemplateEnd := TemplateBeg + TemplateLen;
  // Count result length for speed optimization.
  ResultLen := 0;
  p := TemplateBeg;
  while p < TemplateEnd do
  begin
    Ch := p^;
    Inc(p);
    if Ch = '$' then
      n := FSubExprIndexes[ParseVarName(p)]
    else
      n := -1;
    if n >= 0 then
    begin
      Inc(ResultLen, endp[n] - startp[n]);
    end
    else
    begin
      if (Ch = EscChar) and (p < TemplateEnd) then
      begin // quoted or special char followed
        Ch := p^;
        Inc(p);
        case Ch of
          'n':
            Inc(ResultLen, length(FReplaceLineEnd));
          'u', 'l', 'U', 'L': { OP_NOTHING }
            ;
          'x':
            begin
              Inc(ResultLen);
              if (p^ = '{') then
              begin // skip \x{....}
                while ((p^ <> '}') and (p < TemplateEnd)) do
                  p := p + 1;
                p := p + 1;
              end
              else
                p := p + 2 // skip \x..
            end;
        else
          Inc(ResultLen);
        end;
      end
      else
        Inc(ResultLen);
    end;
  end;
  // Get memory. We do it once and it significant speed up work !
  if ResultLen = 0 then
  begin
    Result := '';
    Exit;
  end;
  // SetString (Result, nil, ResultLen);
  SetLength(Result, ResultLen);
  // Fill Result
  ResultPtr := Pointer(Result);
  p := TemplateBeg;
  Mode := smodeNormal;
  while p < TemplateEnd do
  begin
    Ch := p^;
    p0 := p;
    Inc(p);
    p1 := p;
    if Ch = '$' then
      n := FSubExprIndexes[ParseVarName(p)]
    else
      n := -1;
    if (n >= 0) then
    begin
      p0 := startp[n];
      p1 := endp[n];
    end
    else
    begin
      if (Ch = EscChar) and (p < TemplateEnd) then
      begin // quoted or special char followed
        Ch := p^;
        Inc(p);
        case Ch of
          'n':
            begin
              p0 := @FReplaceLineEnd[1];
              p1 := p0 + length(FReplaceLineEnd);
            end;
          'x', 't', 'r', 'f', 'a', 'e':
            begin
              p := p - 1;
              // UnquoteChar expects the escaped char under the pointer
              QuotedChar := UnQuoteChar(p);
              p := p + 1;
              // Skip after last part of the escaped sequence - UnquoteChar stops on the last symbol of it
              p0 := @QuotedChar;
              p1 := p0 + 1;
            end;
          'l':
            begin
              Mode := smodeOneLower;
              p1 := p0;
            end;
          'L':
            begin
              Mode := smodeAllLower;
              p1 := p0;
            end;
          'u':
            begin
              Mode := smodeOneUpper;
              p1 := p0;
            end;
          'U':
            begin
              Mode := smodeAllUpper;
              p1 := p0;
            end;
        else
          begin
            Inc(p0);
            Inc(p1);
          end;
        end;
      end
    end;
    if p0 < p1 then
    begin
      while p0 < p1 do
      begin
        case Mode of
          smodeOneLower, smodeAllLower:
            begin
              Ch := p0^;
              Ch := _LowerCase(Ch);
              ResultPtr^ := Ch;
              if Mode = smodeOneLower then
                Mode := smodeNormal;
            end;
          smodeOneUpper, smodeAllUpper:
            begin
              Ch := p0^;
              Ch := _UpperCase(Ch);
              ResultPtr^ := Ch;
              if Mode = smodeOneUpper then
                Mode := smodeNormal;
            end;
        else
          ResultPtr^ := p0^;
        end;
        Inc(ResultPtr);
        Inc(p0);
      end;
      Mode := smodeNormal;
    end;
  end;
end; { of function TRegExpr.Substitute
  -------------------------------------------------------------- }

procedure TRegExpr.Split(const AInputStr: RegExprString; APieces: TStrings);
var
  PrevPos: PtrInt;
begin
  PrevPos := 1;
  if Exec(AInputStr) then
    repeat
      APieces.Add(System.Copy(AInputStr, PrevPos, MatchPos[0] - PrevPos));
      PrevPos := MatchPos[0] + MatchLen[0];
    until not ExecNext;
  APieces.Add(System.Copy(AInputStr, PrevPos, MaxInt)); // Tail
end; { of procedure TRegExpr.Split
  -------------------------------------------------------------- }

function TRegExpr.Replace(const AInputStr: RegExprString;
  const AReplaceStr: RegExprString;
  AUseSubstitution: boolean{$IFDEF DefParam} = False{$ENDIF}): RegExprString;
var
  PrevPos: PtrInt;
begin
  Result := '';
  PrevPos := 1;
  if Exec(AInputStr) then
    repeat
      Result := Result + System.Copy(AInputStr, PrevPos, MatchPos[0] - PrevPos);
      if AUseSubstitution // ###0.946
      then
        Result := Result + Substitute(AReplaceStr)
      else
        Result := Result + AReplaceStr;
      PrevPos := MatchPos[0] + MatchLen[0];
    until not ExecNext;
  Result := Result + System.Copy(AInputStr, PrevPos, MaxInt); // Tail
end; { of function TRegExpr.Replace
  -------------------------------------------------------------- }

function TRegExpr.ReplaceEx(const AInputStr: RegExprString;
  AReplaceFunc: TRegExprReplaceFunction): RegExprString;
var
  PrevPos: PtrInt;
begin
  Result := '';
  PrevPos := 1;
  if Exec(AInputStr) then
    repeat
      Result := Result + System.Copy(AInputStr, PrevPos, MatchPos[0] - PrevPos)
        + AReplaceFunc(Self);
      PrevPos := MatchPos[0] + MatchLen[0];
    until not ExecNext;
  Result := Result + System.Copy(AInputStr, PrevPos, MaxInt); // Tail
end; { of function TRegExpr.ReplaceEx
  -------------------------------------------------------------- }

{$IFDEF OverMeth}
function TRegExpr.Replace(const AInputStr: RegExprString;
  AReplaceFunc: TRegExprReplaceFunction): RegExprString;
begin
  Result := ReplaceEx(AInputStr, AReplaceFunc);
end; { of function TRegExpr.Replace
  -------------------------------------------------------------- }
{$ENDIF}
{ ============================================================= }
{ ====================== Debug section ======================== }
{ ============================================================= }

{$IFDEF RegExpPCodeDump}

function TRegExpr.DumpOp(op: TREOp): RegExprString;
// printable representation of opcode
begin
  case op of
    OP_BOL:
      Result := 'BOL';
    OP_EOL:
      Result := 'EOL';
    OP_BOLML:
      Result := 'BOLML';
    OP_EOLML:
      Result := 'EOLML';
    OP_BOUND:
      Result := 'BOUND'; // ###0.943
    OP_NOTBOUND:
      Result := 'NOTBOUND'; // ###0.943
    OP_ANY:
      Result := 'ANY';
    OP_ANYML:
      Result := 'ANYML'; // ###0.941
    OP_ANYLETTER:
      Result := 'ANYLETTER';
    OP_NOTLETTER:
      Result := 'NOTLETTER';
    OP_ANYDIGIT:
      Result := 'ANYDIGIT';
    OP_NOTDIGIT:
      Result := 'NOTDIGIT';
    OP_ANYSPACE:
      Result := 'ANYSPACE';
    OP_NOTSPACE:
      Result := 'NOTSPACE';
    OP_ANYHORZSEP:
      Result := 'ANYHORZSEP';
    OP_NOTHORZSEP:
      Result := 'NOTHORZSEP';
    OP_ANYVERTSEP:
      Result := 'ANYVERTSEP';
    OP_NOTVERTSEP:
      Result := 'NOTVERTSEP';
    OP_ANYOF:
      Result := 'ANYOF';
    OP_ANYBUT:
      Result := 'ANYBUT';
    OP_ANYOFCI:
      Result := 'ANYOF/CI';
    OP_ANYBUTCI:
      Result := 'ANYBUT/CI';
    OP_BRANCH:
      Result := 'BRANCH';
    OP_EXACTLY:
      Result := 'EXACTLY';
    OP_EXACTLYCI:
      Result := 'EXACTLY/CI';
    OP_NOTHING:
      Result := 'NOTHING';
    OP_COMMENT:
      Result := 'COMMENT';
    OP_BACK:
      Result := 'BACK';
    OP_EEND:
      Result := 'END';
    OP_BSUBEXP:
      Result := 'BSUBEXP';
    OP_BSUBEXPCI:
      Result := 'BSUBEXP/CI';
    Succ(OP_OPEN) .. TREOp(Ord(OP_OPEN) + NSUBEXP - 1): // ###0.929
      Result := Format('OPEN[%d]', [Ord(op) - Ord(OP_OPEN)]);
    Succ(OP_CLOSE) .. TREOp(Ord(OP_CLOSE) + NSUBEXP - 1): // ###0.929
      Result := Format('CLOSE[%d]', [Ord(op) - Ord(OP_CLOSE)]);
    OP_STAR:
      Result := 'STAR';
    OP_PLUS:
      Result := 'PLUS';
    OP_BRACES:
      Result := 'BRACES';
    {$IFDEF ComplexBraces}
    OP_LOOPENTRY:
      Result := 'LOOPENTRY'; // ###0.925
    OP_LOOP:
      Result := 'LOOP'; // ###0.925
    OP_LOOPNG:
      Result := 'LOOPNG'; // ###0.940
    {$ENDIF}
    OP_ANYOFTINYSET:
      Result := 'ANYOFTINYSET';
    OP_ANYBUTTINYSET:
      Result := 'ANYBUTTINYSET';
    {$IFDEF UseSetOfChar} // ###0.929
    OP_ANYOFFULLSET:
      Result := 'ANYOFFULLSET';
    {$ENDIF}
    OP_STARNG:
      Result := 'STARNG'; // ###0.940
    OP_PLUSNG:
      Result := 'PLUSNG'; // ###0.940
    OP_BRACESNG:
      Result := 'BRACESNG'; // ###0.940
  else
    Error(reeDumpCorruptedOpcode);
  end; { of case op }
  Result := ':' + Result;
end; { of function TRegExpr.DumpOp
  -------------------------------------------------------------- }

function TRegExpr.Dump: RegExprString;
// dump a regexp in vaguely comprehensible form
var
  s: PRegExprChar;
  op: TREOp; // Arbitrary non-END op.
  next: PRegExprChar;
  i: PtrInt;
  Diff: PtrInt;
  {$IFDEF UseSetOfChar} // ###0.929
  Ch: REChar;
  {$ENDIF}
  function PrintableChar(AChar: REChar): string; {$IFDEF InlineFuncs}inline;{$ENDIF}
  begin
    if AChar < ' ' then
      Result := '#' + IntToStr(Ord(AChar))
    else
      Result := AChar;
  end;

begin
  if not IsProgrammOk // ###0.929
  then
    Exit;

  op := OP_EXACTLY;
  Result := '';
  s := programm + REOpSz;
  while op <> OP_EEND do
  begin // While that wasn't END last time...
    op := s^;
    Result := Result + Format('%2d%s', [s - programm, DumpOp(s^)]);
    // Where, what.
    next := regnext(s);
    if next = nil // Next ptr.
    then
      Result := Result + ' (0)'
    else
    begin
      if next > s
      // ###0.948 PWideChar subtraction workaround (see comments in Tail method for details)
      then
        Diff := next - s
      else
        Diff := -(s - next);
      Result := Result + Format(' (%d) ', [(s - programm) + Diff]);
    end;
    Inc(s, REOpSz + RENextOffSz);
    if (op = OP_ANYOF) or (op = OP_ANYOFCI) or (op = OP_ANYBUT) or (op = OP_ANYBUTCI) or
      (op = OP_EXACTLY) or (op = OP_EXACTLYCI) then
    begin
      // Literal string, where present.
      while s^ <> #0 do
      begin
        Result := Result + PrintableChar(s^);
        Inc(s);
      end;
      Inc(s);
    end;
    if (op = OP_ANYOFTINYSET) or (op = OP_ANYBUTTINYSET) then
    begin
      for i := 1 to TinySetLen do
      begin
        Result := Result + s^;
        Inc(s);
      end;
    end;
    if (op = OP_BSUBEXP) or (op = OP_BSUBEXPCI) then
    begin
      Result := Result + ' \' + IntToStr(Ord(s^));
      Inc(s);
    end;
    {$IFDEF UseSetOfChar} // ###0.929
    if op = OP_ANYOFFULLSET then
    begin
      for Ch := #0 to #255 do
        if Ch in PSetOfREChar(s)^ then
          Result := Result + PrintableChar(Ch);
      Inc(s, SizeOf(TSetOfREChar));
    end;
    {$ENDIF}
    if (op = OP_BRACES) or (op = OP_BRACESNG) then
    begin // ###0.941
      // show min/max argument of OP_BRACES operator
      Result := Result + Format('{%d,%d}', [PREBracesArg(AlignToInt(s))^,
        PREBracesArg(AlignToInt(s + REBracesArgSz))^]);
      Inc(s, REBracesArgSz * 2);
    end;
    {$IFDEF ComplexBraces}
    if (op = OP_LOOP) or (op = OP_LOOPNG) then
    begin // ###0.940
      Result := Result + Format(' -> (%d) {%d,%d}',
        [(s - programm - (REOpSz + RENextOffSz)) +
        PRENextOff(AlignToPtr(s + 2 * REBracesArgSz))^,
        PREBracesArg(AlignToInt(s))^,
        PREBracesArg(AlignToInt(s + REBracesArgSz))^]);
      Inc(s, 2 * REBracesArgSz + RENextOffSz);
    end;
    {$ENDIF}
    Result := Result + #$d#$a;
  end; { of while }

  // Header fields of interest.

  if regstart <> #0 then
    Result := Result + 'start ' + regstart;
  if reganch <> #0 then
    Result := Result + 'anchored ';
  if regmust <> nil then
    Result := Result + 'must have ' + regmust;
  {$IFDEF UseFirstCharSet} // ###0.929
  Result := Result + #$d#$a'FirstCharSet:';
  for Ch := #0 to #255 do
    if Ch in FirstCharSet then
    begin
      if Ch < ' ' then
        Result := Result + PrintableChar(Ch) // ###0.948
      else
        Result := Result + Ch;
    end;
  {$ENDIF}
  Result := Result + #$d#$a;
end; { of function TRegExpr.Dump
  -------------------------------------------------------------- }
{$ENDIF}

{$IFDEF reRealExceptionAddr}
{$OPTIMIZATION ON}
// ReturnAddr works correctly only if compiler optimization is ON
// I placed this method at very end of unit because there are no
// way to restore compiler optimization flag ...
{$ENDIF}

procedure TRegExpr.Error(AErrorID: integer);
  {$IFDEF reRealExceptionAddr}
  function ReturnAddr: Pointer; // ###0.938
  asm
    mov  eax,[ebp+4]
  end;
  {$ENDIF}
var
  e: ERegExpr;
begin
  fLastError := AErrorID; // dummy stub - useless because will raise exception
  if AErrorID < 1000 // compilation error ?
  then
    e := ERegExpr.Create(ErrorMsg(AErrorID) // yes - show error pos
      + ' (pos ' + IntToStr(CompilerErrorPos) + ')')
  else
    e := ERegExpr.Create(ErrorMsg(AErrorID));
  e.ErrorCode := AErrorID;
  e.CompilerErrorPos := CompilerErrorPos;
  raise e
  {$IFDEF reRealExceptionAddr}
    At ReturnAddr; // ###0.938
  {$ENDIF}
end; { of procedure TRegExpr.Error
  -------------------------------------------------------------- }

(*
  PCode persistence:
  FirstCharSet
  programm, regsize
  regstart // -> programm
  reganch // -> programm
  regmust, regmlen // -> programm
  fExprIsCompiled
*)

// be carefull - placed here code will be always compiled with
// compiler optimization flag

{$IFDEF FPC}

initialization

RegExprInvertCaseFunction := TRegExpr.InvertCaseFunction;

{$ENDIF}

end.
