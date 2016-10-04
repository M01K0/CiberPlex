{Unidad con definiciones básicas para la tarificación y el enrutamiento. Incluye:
* Definiciones de los registros de tarifas y rutas.
* La definición de los contenedores para las tablas de tarifas y rutas: TNiloMTabTar y
TNiloMTabRut.
* Rutinas para el pre-procesamiento del tarifario y tabla de rutas.
}
unit CibNiloMTarifRut;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, fgl, Types, math, LCLProc, Graphics, SynEditHighlighter,
  strutils, MisUtils, SynFacilHighlighter, XpresBas;
Const
  MAX_DEFINICIONES = 50;
type
  { regTarifa }
  //Define el tipo que almacena una tarifa (Una línea del archivo tarifario)
  regTarifa = class
    //Campos leidos directamente del archivo tarifario
    serie   : String;     //serie de la tarifa
    costop  : String;     {costo del paso tal y como se lee del tarifario
                          (puede incluir sintaxis de subpaso o costo de paso 1)}
    categoria : string;   //categoría de llamada
    descripcion: String;  //Descripción de la serie
    //Campos calculados
    HaySubPaso : Boolean; //Indica si hay subpaso (y por lo tanto subcosto)
    npaso    : Integer;   //Valor del paso en segundos
    Nsubpaso : Integer;   //Valor del subpaso en segundos
    Ncosto   : Double;    //Valor del costo en flotante
    Nsubcosto: Double;    //Valor del subcosto en flotante
    HayCPaso1: Boolean;   //Indica si hay costo de paso 1
    NCpaso1  : Double;    //Costo del Paso 1 en flotante
    function  paso: String;
    procedure assign(reg: regTarifa);   //para copia
  end;
  regTarifa_list = specialize TFPGObjectList<regTarifa>;

  //Define el tipo que almacena una ruta (Una línea del archivo de rutas)

  { regRuta }

  regRuta = class
    serie : string;    //Serie digitada
    numdig: integer;   //Número de digitos
    codPre: string;    //Cósigos de Prefijos
    indNT : integer;   //índice a colección. Solo se usa en "rutasA"
    procedure assign(reg: regRuta);   //para copia
  end;
  regRuta_list = specialize TFPGObjectList<regRuta>;




  //Tipo de evento para mensajes
  TEvLogInfo = function(mensaje: string): integer of object;

type   //Tipos para manejo de definiciones
  TNilDefinicion = class  //estructura de definicion
    con : String;   //contenido de la definicion
    nom : String;   //nombre de la definicion
    nlin : Integer; //número de línea donde se encuentra la definición
  end;
  TNilDefinicion_list = specialize TFPGObjectList<TNilDefinicion>;

  { TContextTar }
  {Contexto ampliado para manejar el tarifario}
  TContextTar = class(TContext)
  private
    xLex : TSynFacilSyn;
    procedure ProcesaLinea2(var linea: string; var fil: Integer; recMoneda: boolean=
      true);
  public
    msjError: string;
    tkPrepro: TSynHighlighterAttributes;  //atributo para procesar definiciones
    definiciones: TNilDefinicion_list;
    function ExisteDefinicion(def: String): TNilDefinicion;
    function CogerCad: string;
    function CogerInt: integer;
    function CogerFloat: double;
  private //Funciones de identificación del token actual
    function EsDEFINIR: boolean;
    function EsCOMO: boolean;
    function EsFINDEFINIR: boolean;
    function EsMoneda: boolean;
    function EsNumero: boolean;
    function EsCadena: boolean;
    function EsIdentif: boolean;
    function EsDefinicion(var def: TNilDefinicion): boolean;
    procedure AgregaDefinicion(const nom, con: string; numlin: integer);
  public //Constructor y destructor
    constructor Create;
    destructor Destroy; override;
  end;

type
  { TNiloMTab }
  {Clase padre para los contenedores de tabla de tarifas y de rutas}
  TNiloMTab = class
  private //funciones para registrar mensajes
    function PLogErr(mensaje: string): integer;
    function PLogInf(mensaje: String): integer;
  public  //Eventos para registrar mensajes
    OnLogErr: TEvLogInfo;
    OnLogInf: TEvLogInfo;
  public
    msjError: string;    //mensaje de error
    filError, colError: integer;  //posición del error
  end;

  { TNiloMTabTar }
  {Contenedor para la tabla de tarifas}
  TNiloMTabTar = class(TNiloMTab)
  private
    minCostop, maxCostop: Double;
    nlin : integer;
    ctx  : TContextTar;   //contexto para procesar el tarifario
    procedure ActualizarMinMax;
    function BuscaTarifaI(num: String): regTarifa;
    function regTarif_DeEdi(r: regTarifa; cad: string): string;
    procedure VerificaTarifa(r: regTarifa; facCmoneda: double);
    procedure VerificFinal(var numlin: Integer);
  public
    monNil : string;
    tarifasTmp: regTarifa_list;
    tarifas: regTarifa_list;
    tarNula: regTarifa;  //tarifa con valores nulos
    function BuscaTarifa(num: String): regTarifa;
    procedure CargarTarifas(lins: TStrings; facCmoneda: double);
//    function CargarTarifas(archivo: String; facCmoneda: double): Integer;
  public  //Constructor y destructor
    constructor Create;
    destructor Destroy; override;
  end;

  { TNiloMTabRut }
  {Contenedor para la tabla de rutas}
  TNiloMTabRut = class(TNiloMTab)
  private
    nlin : integer;
    ctx  : TContextTar;   //contexto para procesar el tarifario
    function CodifPref(codStr: string): byte;
    function regRuta_DeEdi(r: regRuta; cad: string): string;
  public
    rutasTmp: regRuta_list;
    rutas: regRuta_list;
    procedure CargarRutas(lins: TStrings);
  public  //Constructor y destructor
    constructor Create;
    destructor Destroy; override;
  end;

  function LeeCdrNilo(linea: String;
      var serie, canal, durac, Costo, costoA, canalS, digitado, descripc: String): string;
  procedure ConfigurarSintaxisTarif(hl: TSynFacilSyn; var attPrepro: TSynHighlighterAttributes);
  procedure ConfigurarSintaxisRutas(hl: TSynFacilSyn; var attPrepro: TSynHighlighterAttributes);

implementation
Function SeriesIguales(ser1, ser2 : string): Boolean;
//Compara dos series considerando que "ser2" puede tener el comodín "?"
var
  i : Integer;
begin
    if Length(ser1) <> Length(ser2) Then exit(false);
    if Length(ser1) = 0 Then exit(true);
    For i := 1 To Length(ser1) do begin
        If MidStr(ser2, i, 1) <> '?' Then  begin //el comodín coincide con cualquier cosa
            If MidStr(ser1, i, 1) <> MidStr(ser2, i, 1) Then
                exit(false);
        End;
    end;
    Result := True;   //concidieron
End;
function LeeCdrNilo(linea: String;
    var serie, canal, durac, Costo, costoA, canalS, digitado, descripc: String): string;
{Lee el CDR del NILO-m. Si hay error, devuelve cadena con mensaje.}
var
  a: TStringDynArray;
begin
  //Lee sólo los campos generados por el NILO-m
  Result := '';
  a := Explode(';', linea);
  If High(a) < 7 then begin
      Result := 'Error leyendo cdr. Faltan campos: ' + linea;
      exit;
  end;
  serie   := copy(a[0], 2, 3);    //toma serie
  canal   := a[1];
  durac   := copy(a[2], 1, 3) + ':' + copy(a[2], 4, 2);
  Costo   := a[3];
  costoA  := a[4];     //costo acumulado
  canalS  := a[5];
  digitado:= a[6];
  descripc:= a[7];
end;
procedure ConfigurarSintaxisTarif(hl: TSynFacilSyn; var attPrepro: TSynHighlighterAttributes);
{Configura la sintaxis de un resaltador, para que reconozca la sintaxis de un tarifario
para un NILO-mC/D/E}
begin
  hl.ClearSpecials;               //para empezar a definir tokens
  hl.CreateAttributes;            //Limpia atributos
  hl.ClearMethodTables;           //limpìa tabla de métodos
  attPrepro := hl.NewTokType('preprocesador');
  attPrepro.Foreground:=clRed;        //color de texto
  attPrepro.Style:=[fsBold];
  hl.tkKeyword.Style:=[fsBold];
  //Define tokens. Notar que la definición de número es particular
  hl.DefTokIdentif('[$A-Za-z_]', '[A-Za-z0-9_]*');
  hl.DefTokContent('[0-9#*]', '[0-9#*.]*', hl.tkNumber);
  hl.DefTokDelim('"','"', hl.tkString);
  hl.DefTokDelim('//','',hl.tkComment);
  hl.tkComment.Style:=[];
  //define palabras claves
  hl.AddIdentSpecList('DEFINIR COMO FINDEFINIR', attPrepro);
  hl.AddIdentSpecList('MONEDA', hl.tkKeyword);
  hl.Rebuild;  //reconstruye
end;
procedure ConfigurarSintaxisRutas(hl: TSynFacilSyn; var attPrepro: TSynHighlighterAttributes);
{Configura la sintaxis de un resaltador, para que reconozca la sintaxis de una tabla de
rutas para un NILO-mC/D/E}
var
  tkPreproc: TSynHighlighterAttributes;
begin
  hl.ClearSpecials;               //para empezar a definir tokens
  hl.CreateAttributes;            //Limpia atributos
  hl.ClearMethodTables;           //limpìa tabla de métodos
  tkPreproc := hl.NewTokType('preprocesador');
  tkPreproc.Foreground:=clRed;        //color de texto
  tkPreproc.Style:=[fsBold];
  hl.tkKeyword.Style:=[fsBold];
  //Define tokens. Notar que la definición de número es particular
  hl.DefTokIdentif('[$A-Za-z_]', '[A-Za-z0-9_]*');
  hl.DefTokContent('[0-9#*]', '[0-9#*.]*', hl.tkNumber);
  hl.DefTokDelim('"','"', hl.tkString);
  hl.DefTokDelim('//','',hl.tkComment);
  hl.tkComment.Style:=[];
  //define palabras claves
  hl.AddIdentSpecList('DEFINIR COMO FINDEFINIR', tkPreproc);
  hl.Rebuild;  //reconstruye
end;

{ regTarifa }
function regTarifa.paso: String;
{Valor del paso en segundos tal y como se leería del archivo tarifario}
begin
  if HaySubPaso then Result:=IntToStr(npaso)+'/'+IntToStr(Nsubpaso)
  else Result:=IntToStr(npaso);
end;
procedure regTarifa.assign(reg: regTarifa);
begin
  serie       := reg.serie;
  costop      := reg.costop;
  categoria   := reg.categoria;
  descripcion := reg.descripcion;
  //Campos calculados
  HaySubPaso  := reg.HaySubPaso;
  npaso       := reg.npaso;
  Nsubpaso    := reg.Nsubpaso;
  Ncosto      := reg.Ncosto;
  Nsubcosto   := reg.Nsubcosto;
  HayCPaso1   := reg.HayCPaso1;
  NCpaso1     := reg.NCpaso1;
end;
{ regRuta }
procedure regRuta.assign(reg: regRuta);
begin
  serie  := reg.serie;
  numdig := reg.numdig;
  codPre := reg.codPre;
  indNT  := reg.indNT;
end;
{ TContextTar }
function TContextTar.ExisteDefinicion(def: String): TNilDefinicion;
//Si una variable está definida devuelve su referencia, sino, devuelve NIL.
var
  d : TNilDefinicion;
  defM: string;
begin
  defM := upcase(def);
  for d in definiciones do begin
    if Upcase(d.nom) = defM Then exit(d);
  end;
  exit(nil);
end;
function TContextTar.CogerCad: string;
{Devuelve el token actual, como cadena y pasa al siguiente token.}
begin
  Result := Token;
  Next;   //pasa al siguiente
end;
function TContextTar.CogerInt: integer;
{Devuelve el token actual, como entero y pasa al siguiente token. Si no puede convertir
al token en entero, devuelve "MaxInt"}
begin
  if not TryStrToInt(Token, Result) then Result := MaxInt;
  Next;
end;
function TContextTar.CogerFloat: double;
{Devuelve el token actual, como entero y pasa al siguiente token. Si no puede convertir
al token en entero, devuelve "MaxFloat"}
begin
  if not TryStrToFloat(Token, Result) then Result := MaxFloat;
  Next;
end;

//Funciones de identificación del token actual
function TContextTar.EsDEFINIR: boolean;
{Indica si el identificador actual es la directiva DEFINIR}
begin
  Result := (TokenType = tkPrepro) and (upcase(Token) = 'DEFINIR') ;
end;
function TContextTar.EsCOMO: boolean;
begin
  Result := (TokenType = tkPrepro) and (upcase(Token) = 'COMO') ;
end;
function TContextTar.EsFINDEFINIR: boolean;
begin
  Result := (TokenType = tkPrepro) and (upcase(Token) = 'FINDEFINIR') ;
end;
function TContextTar.EsMoneda: boolean;
begin
  Result := (TokenType = lex.tkKeyword) and (upcase(Token) = 'MONEDA') ;
end;
function TContextTar.EsNumero: boolean;
begin
  Result := TokenType = lex.tkNumber;
end;
function TContextTar.EsCadena: boolean;
begin
  Result := TokenType = lex.tkString;
end;
function TContextTar.EsIdentif: boolean;
begin
  Result := TokenType = lex.tkIdentif;
end;
function TContextTar.EsDefinicion(var def: TNilDefinicion): boolean;
{Indica si el token actual es una definición. De ser así, devuelve TRUE y actualiza la
referencia.}
begin
  if TokenType<>lex.tkIdentif then exit(false);  //no es identificador
  def := ExisteDefinicion(token);  //busca el identificador
  Result := def<>nil;
end;
procedure TContextTar.AgregaDefinicion(const nom, con: string; numlin: integer);
{Agrega una definición a la lista}
var
  def: TNilDefinicion;
begin
  def := TNilDefinicion.Create;
  def.nom:=nom;
  def.con:=con;
  def.nlin:=numlin;
  definiciones.Add(def);
end;
procedure TContextTar.ProcesaLinea2(var linea : string; var fil : Integer;
    recMoneda: boolean = true);
{Hace la limpieza de una línea que va a ser leida del tarifario o del
archivo de rutas.
Los archivos a leer se procesan por líneas, por eso esta rutina solo trabaja con
una línea.
"recMoneda" indica que se debe reconocer la definición de MONEDA.}
var
  ident, conten : string;
  mon, lintmp, tok: string;
  def: TNilDefinicion;
begin
  SetSource(linea);
  lintmp := '';  //limpia para acumular
  msjError := '';
  while not Eof do begin
//    debugln(TokenType.Name + ':' + Token);
    if recMoneda and EsMoneda then begin
      Next;  //coge identificador
      SkipWhites;
      if Token<>'=' then begin
        msjError := 'Se esperaba "="'; exit;
      end;
      //Se toma el símbolo de moneda
      Next;
      SkipWhites;
      mon := '';  //toma símbolo hasta el final
      while not EsFINDEFINIR and not eof do begin
        mon := mon + token;
        next;
      end;
      AgregaDefinicion('MONEDA', mon, fil);
      linea := '';  //indica que ya lo procesó
      exit;         //sale
    end else if EsDEFINIR then begin
      Next;  //coge identificador
      SkipWhites;
      if TokenType<> lex.tkIdentif then begin
        msjError := 'Se esperaba identificador.'; exit;
      end;
      ident := token;  //toma identificador
      Next;  //coge identificador
      SkipWhites;
      if EsCOMO then begin
        //Forma DEFINIR xxx COMO ... FINDEFINIR
        Next;
        //toma hasta encontrar FINDEFINIR
        conten := '';
        while not EsFINDEFINIR and not eof do begin
          conten := conten + token;
          next;
        end;
        if eof then begin
          msjError := 'Se esperaba "FINDEFINIR".'; exit;
        end;
        AgregaDefinicion(ident, conten, fil);
        linea := '';  //indica que ya lo procesó
        exit;         //sale
      end else if Token = '=' then begin
        //Forma DEFINIR xxx = ...
        Next;
        //toma hasta fin de línea
        conten := '';
        while not eof do begin
          if TokenType <> lex.tkComment then conten := conten + token;
          next;
        end;
        AgregaDefinicion(ident, conten, fil);
        linea := '';  //indica que ya lo procesó
        exit;
      end else begin
        msjError := 'Se esperaba "COMO".';
        exit;
      end;
    end else if EsDefinicion(def) then begin
      //hay una definición que hay que reemplazar
      tok := def.con;   //reemplaza con su contenido
    end else if TokenType = lex.tkComment then begin
      //es un comentario
      tok := '';   //elimina
    end else begin  //es un token común
      tok := Token;
    end;
    lintmp := lintmp + tok;  //acumula
    Next;
  end;
  //Terminó de procesar. Devuelve la línea procesada
  linea := lintmp;
end;
constructor TContextTar.Create;
begin
  inherited Create;
  xLex := TSynFacilSyn.Create(nil);
  DefSyn(xLex);
  ConfigurarSintaxisTarif(xLex, tkPrepro);  //usa la misma sintaxis que el resaltador
  definiciones:= TNilDefinicion_list.Create(true);
end;
destructor TContextTar.Destroy;
begin
  definiciones.Destroy;
  xLex.Destroy;
  inherited Destroy;
end;
{ TNiloMTab }
function TNiloMTab.PLogErr(mensaje: string): integer;
begin
  Result := 0;
  if OnLogErr<>nil then Result := OnLogErr(mensaje);
end;
function TNiloMTab.PLogInf(mensaje: String): integer;
begin
  Result := 0;
  if OnLogInf<>nil then Result := OnLogInf(mensaje);
end;
{ TNiloMTabTar }
procedure TNiloMTabTar.ActualizarMinMax;
//Actualiza valores máximo y mínimo
var
  tar: regTarifa;
  cp: Double;
begin
  For tar in tarifas  do begin
    cp := tar.Ncosto;
    If cp < minCostop Then minCostop := cp;
    If cp > maxCostop Then maxCostop := cp;
    If tar.HaySubPaso Then begin
        cp := tar.NCpaso1;
        If cp < minCostop Then minCostop := cp;
        If cp > maxCostop Then maxCostop := cp;
    End;
  end;
end;
function TNiloMTabTar.BuscaTarifaI(num: String): regTarifa;
{Devuelve la referencia a una Tarifa para la serie indicada. Si no
encuentra una concidencia, devuelve NIL.
Cuando hay pocos dígitos, no es preciso en ubicar la tarifa.}
var
  clave : string;
  tar: regTarifa;
begin
  clave := num;
  While Length(clave) > 0 do begin
      for tar in Tarifas do begin
          if SeriesIguales(clave, tar.serie) Then exit(tar);
      end;
      clave := LeftStr(num, Length(clave) - 1);
  end;
  //No encuentra concidencia
  Result := nil;
end;
function TNiloMTabTar.regTarif_DeEdi(r: regTarifa; cad: string): string;
{Convierte cadena de texto en registro. Se usa para leer del editor
Se asume que el editor sólo tiene espacios como separadores. Las tabulaciones
deben haberse reemplazado previamente. Si hay error, devuelve mensaje como cadena.}
begin
  Result := '';   //por defecto no hay error
  ctx.SetSource(cad);  //carga lexer
  //Coge SERIE
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsNumero then exit('Se esperaba número (0..9,#,*) en campo SERIE.');
  r.serie := ctx.CogerCad;  //lee y pasa al siguiente

  //Coge PASO
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  r.npaso := ctx.CogerInt;  //lee y pasa al siguiente
  if r.npaso = MaxInt then exit('Se esperaba número (0..9) en campo PASO.');
  if ctx.Token='/' then begin
    //Hay subpaso
    r.HaySubPaso:=true;
    ctx.Next;  //pasa al siguiente
    if ctx.Eof then exit('Campos insuficientes');
//    if not ctx.EsNumero then exit('Se esperaba número después de "/".');
    r.Nsubpaso := ctx.CogerInt;  //coge subpaso
    if r.Nsubpaso = MaxInt then exit('Se esperaba número después de "/".');
  end;

  //Coge COSTO
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsNumero then exit('Se esperaba número.');
  r.costop := ctx.CogerCad;  //lee y pasa al siguiente

  //Coge CATEGORÍA
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsCadena and not ctx.EsIdentif then exit('Se esperaba cadena o identificador en CATEGORÍA.');
  r.categoria := ctx.CogerCad;  //lee y pasa al siguiente

  //Coge DESCRIPCIÓN
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsCadena then exit('Se esperaba cadena en campo DESCRIPCIÓN.');
  r.descripcion := ctx.CogerCad;  //lee y pasa al siguiente

  ctx.SkipWhites;
  if not ctx.Eof then exit('Demasiados campos');
end;
procedure TNiloMTabTar.VerificaTarifa(r: regTarifa; facCmoneda: double);
{Verifica si el registro de tarifa cumple con la definición.
Realiza además las adaptaciones necesarias con los campos y completa
los campos calculados.
El error se devuelve en "MsjError"}
var
  costop: String;
  posi : Integer;
  a: TStringDynArray;
  dif: Double;
begin
    msjError := '';   //Inicia mensaje
    //------------------ Verifica costo --------------------
    costop := r.costop;
    if costop[1] in ['0'..'9'] Then begin //Verifica costo
        if Pos(',', costop) <> 0 Then begin  //Verifica costo
            msjError := 'Error en serie: ' + r.serie + '. No se permite uso de coma en costo.';
            Exit;
        end;
        //Verifica si hay costo de paso 1
        If pos(':', costop) <> 0 Then begin
            posi := pos(':', costop);    //lee posición
            r.NCpaso1 := StrToFloat(LeftStr(costop, posi - 1));  //toma costo de paso 1
            r.HayCPaso1 := True;
            costop := copy(costop, posi + 1, length(costop));  //recorta para seguir leyendo
        End;
        //Continúa verficando
        If r.HaySubPaso Then begin
            If pos('/', costop) <> 0 Then begin    //Debería haber subcosto
                a := Explode('/', costop);
                r.Ncosto := StrToFloat(a[0]);       //toma costo de paso
                r.Nsubcosto := StrToFloat(a[1]);    //toma sub costo de paso 1
            end Else begin
                msjError := 'Error en serie: "' + r.serie + '". Se esperaba subcosto';
                Exit;
            End;
        end Else begin   //No hay subpaso, No debe haber subcosto
            If pos('/', costop) <> 0 Then begin
                msjError := 'Error en serie: "' + r.serie + '". No se esperaba subcosto';
                Exit;
            end Else begin
                r.Ncosto := StrToFloat(costop);       //toma costo
            End;
        End;
    end Else begin
        msjError := 'Error en serie: "' + r.serie + '". Costo debe ser númerico';
        Exit;
    End;
    //--------------Verifica codificación de paso---------------
//    CPaso = CPSimple(r.costop)  //toma costo de paso ignorando el subpaso
    dif := frac(r.Ncosto / facCmoneda);
    dif := round(dif * 1000000)/1000000;  //redondea por posible error de decimales
    if (dif <> 0) and (dif<>1) Then begin
        msjError := 'Error en serie: "' + r.serie +
                    '". Costo de paso: ' + FloatToStr(r.Ncosto) +
                    ' no se puede codificar con Factor de corrección de moneda: ' +
                    FloatToStr(facCmoneda);
        Exit;
    end;
end;
procedure TNiloMTabTar.VerificFinal(var numlin: Integer);
//Hace las verificaciones de símbolo de moneda
var
  tmp : String;
  def: TNilDefinicion;
begin
    def := ctx.ExisteDefinicion('MONEDA');
    If def <> nil Then begin //Se definio la moneda
        tmp := Trim(def.con);    //lee moneda
        If Length(tmp) > 2 Then begin
            msjError := 'Símbolo de moneda muy largo. Solo se permiten 2 caracteres.';
            numlin := def.nlin;     //posiciona en la definición
        end Else begin
            monNil := LeftStr(tmp + '  ', 2)   //completa con espacios
        End;
    end Else begin           //no se definió la moneda
        msjError := 'No se encontró definición de moneda (MONEDA = XX)';
        numlin := 1;    //posicion al inicio
    End;
end;
function TNiloMTabTar.BuscaTarifa(num: String): regTarifa;
{Devuelve un registro de tipo Tarifa para la serie indicada. Si no
encuentra una concidencia, devuelve un registro con sus campos vacios.
Cuando hay pocos dígitos, no es preciso en ubicar la tarifa.}
begin
  Result := BuscaTarifaI(num);
  if Result = nil then Result := tarNula;
end;
procedure TNiloMTabTar.CargarTarifas(lins: TStrings; facCmoneda: double);
{Carga las tarifas del TStrings indicado.
En condiciones normales actualiza el tarifario.
Si encuentra error, termina la carga y actualiza "msjError", "filError" y "colError".
En ese caso no modifica el tarifario actual.}
var
  linea , l: String;
  i : Integer;
  tar, tar2: regTarifa;
begin
  nlin := 0;
  minCostop := 1000000;
  maxCostop := 0;    //inicia máximo y mínimo
  ctx.definiciones.Clear;   //inicia preprocesador
  tarifasTmp.Clear;
  for l in lins do begin
      linea := l;
      nlin := nlin + 1;
      ctx.ProcesaLinea2(linea, nlin);     //Quita caracteres no válidos
      if ctx.msjError <> '' Then begin
          msjError := ctx.msjError + ' Línea: ' + IntToStr(nlin);
          break;
      end;
      if trim(linea) <> '' then  begin //tiene datos
          tar := regTarifa.Create;
          tarifasTmp.Add(tar);  //agrega nueva tarifa
          msjError := regTarif_DeEdi(tar, linea);
          If msjError <> '' Then break;
          //Verifica si hay duplicidad de serie
          for i:=0 to tarifasTmp.Count-2 do begin  //menos el último
            if tarifasTmp[i].serie = tar.serie then begin
              msjError := 'Serie duplicada: ' + tar.serie + ' Línea: ' + IntToStr(nlin);
              break;
            end;
          end;
          VerificaTarifa(tar, facCmoneda);    //Verifica consistencia y analiza
          If msjError <> '' Then break;
      end;
  end;
  if msjError='' then VerificFinal(nlin);  //verificación final
  //verifica si hubo errores
  if msjError <> '' then begin
    //Salió por error
    PLogErr(msjError);
    filError := nlin;
    colError := ctx.col;  //en donde se quedó la exploración
    exit;    //sale con error y sin actualizar tarifas()
  end;
  //terminó la lectura sin errores
  tarifas.Clear;       //elimina objetos
  for tar in tarifasTmp do begin  //copia las tarifas
    tar2 := regTarifa.Create;  //crea copia para no interferir con objetos administrados
    tar2.assign(tar);    //crea copia
    tarifas.Add(tar2);    //copia tarifas
  end;
  tarifasTmp.Clear;     //libera objetos
  PLogInf(IntToStr(tarifas.Count) + ' tarifas cargadas.');
  ActualizarMinMax;
end;
//Constructor y destructor
constructor TNiloMTabTar.Create;
begin
  tarifasTmp:= regTarifa_list.Create(true);
  tarifas:= regTarifa_list.Create(true);
  tarNula:= regTarifa.Create;  //crea tarifa con campos en blanco
  ctx := TContextTar.Create;
end;
destructor TNiloMTabTar.Destroy;
begin
  ctx.Destroy;
  tarNula.Destroy;
  tarifas.Destroy;
  tarifasTmp.Destroy;
  inherited Destroy;
end;
{ TNiloMTabRut }
function TNiloMTabRut.regRuta_DeEdi(r: regRuta; cad: string): string;
{Convierte cadena de texto en registro. Se usa para leer del editor
Se asume que el editor sólo tiene espacios o tabulaciones como separadores.
Si hay error devuelve mensaje como cadena.}
var
  tmp, codStr: String;
begin
  Result := '';
  ctx.SetSource(cad);
  //Coge SERIE
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsNumero then exit('Se esperaba número (0..9,#,*) en campo SERIE.');
  r.serie := ctx.CogerCad;  //lee y pasa al siguiente

  //Coge NUMDIG
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsNumero then exit('Se esperaba número (0..9,#,*) en campo NUMDIG.');
  r.numdig:=ctx.CogerInt;  //toma como número
  if r.numdig = MaxInt then  exit('Campo NUMDIG debe ser valor numérico.');
  if r.numdig < 0 then exit('Campo NUMDIG debe ser mayor o igual a cero.');
  if r.numdig > 15 then exit('Campo NUMDIG debe ser menor o igual a 15.');

  //Coge CODPRE
  ctx.SkipWhites;
  if ctx.Eof then exit('Campos insuficientes');
  if not ctx.EsCadena then exit('Se esperaba cadena en campo CODPRE.');
  r.codPre := ctx.CogerCad;  //lee y pasa al siguiente
  r.codPre := copy(r.codPre,2,length(r.codPre)-2);  //quita comillas laterales
  //Valida CODPRE
  if length(r.codPre) > 20 then  //Solo se permiten hasta 20 caracteres en el NILO-mC/D/E
    exit('Códigos de prefijo muy largo.');
  tmp := r.codPre;
  while tmp<>'' do begin
    codStr := copy(tmp,1,2);  //toma caracteres
    if length(codStr)<2 then begin
      exit('Código de prefijo incompleto: "'+codStr+'"');
    end;
    Delete(tmp,1,2);          //elimina
    CodifPref(codStr);
    if msjError<>'' then exit(msjError);
  end;
  /////////// Procesamiento final /////////////
  ctx.SkipWhites;
  if not ctx.Eof then exit('Demasiados campos');
end;
function TNiloMTabRut.CodifPref(codStr: string): byte;
//Codifica una cadena de 2 bytes en un código de prefijo de un byte
var
  com, num: char;
  arg: byte;   //argumento
begin
  if length(codStr) <> 2 Then begin
    msjError := 'Error en código de prefijo: ' + codStr;
    exit;
  end;
  com := codStr[1];
  num := codStr[2];
  case num of
  '*': arg := 10;
  '#': arg := 11;
  'p': arg := 12;
  '?': arg := 15;
  '0'..'9': arg := ord(num)-48;  //convierte
  else
    msjError := 'Error en código de prefijo. Dígito inválido en "' + codStr + '"';
    exit;
  end;
  case com of
  'c': Result := $30 + arg;
  'i': Result := $20 + arg;
  'q': Result := $40 + arg;
  'a': Result := $50 + arg;
  else
    msjError := 'Error en código de prefijo. Comando desconocido: "' + codStr + '"';
    exit;
  end;
end;
procedure TNiloMTabRut.CargarRutas(lins: TStrings);
{Carga las rutas del TStrings indicado.
En condiciones normales actualiza la tabla de rutas.
Si encuentra error, termina la carga y actualiza "msjError", "filError" y "colError".
En ese caso no modifica la tabla de rutas actual.}
var
  linea , l: String;
  i : Integer;
  rut, rut2: regRuta;
begin
  nlin := 0;
  ctx.definiciones.Clear;   //inicia preprocesador
  rutasTmp.Clear;
  for l in lins do begin
      linea := l;
      nlin := nlin + 1;
      ctx.ProcesaLinea2(linea, nlin, false);     //Quita caracteres no válidos
      if ctx.msjError <> '' Then begin
          msjError := ctx.msjError + ' Línea: ' + IntToStr(nlin);
          break;
      end;
      if trim(linea) <> '' then  begin //tiene datos
          rut := regRuta.Create;
          rutasTmp.Add(rut);  //agrega nueva tarifa
          msjError := regRuta_DeEdi(rut, linea);
          If msjError <> '' Then break;
          //Verifica si hay duplicidad de serie
          for i:=0 to rutasTmp.Count-2 do begin  //menos el último
            if rutasTmp[i].serie = rut.serie then begin
              msjError := 'Serie duplicada: ' + rut.serie + '. Línea: ' + IntToStr(nlin);
              break;
            end;
          end;
      end;
  end;
  //verifica si hubo errores
  if msjError <> '' then begin
    //Salió por error
    PLogErr(msjError);
    filError := nlin;
    colError := ctx.col;  //en donde se quedó la exploración
    exit;    //sale con error y sin actualizar rutas()
  end;
  //terminó la lectura sin errores
  rutas.Clear;       //elimina objetos
  for rut in rutasTmp do begin  //copia las rutas
    rut2 := regRuta.Create;  //crea copia para no interferir con objetos administrados
    rut2.assign(rut);    //crea copia
    rutas.Add(rut2);    //copia rutas
  end;
  rutasTmp.Clear;     //libera objetos
  PLogInf(IntToStr(rutas.Count) + ' rutas cargadas.');
end;
//Constructor y destructor
constructor TNiloMTabRut.Create;
begin
  rutasTmp:= regRuta_list.Create(true);
  rutas:= regRuta_list.Create(true);
  ctx := TContextTar.Create;
end;
destructor TNiloMTabRut.Destroy;
begin
  ctx.Destroy;
  rutasTmp.Destroy;
  rutas.Destroy;
  inherited Destroy;
end;

end.
