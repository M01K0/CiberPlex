{Unidad que define clases que permiten procesar las tramas e implementar conexiones
mediante TCP/IP, usando hilos.
Los tipos aquí definidos se han penasado para trabajar con Ciberplex, usando las tramas
de comunicación con encabezados de 9 bytes, pero podrían también usarse para otro tipo
de aplicación que desee comunciarse pro Red, siempre que se adapte al formato de las
tramas.

                                        Creado por Tito Hinostroza
                                        Modificado por Tito Hinostroza 27/03/2018
}
unit CibTramas;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, fgl, LCLProc, blcksock;

Const
  ID_ENCABEZ = 15;    //Identificador de mensaje
  TAM_ENCABEZ = 9;    //Tamaño de encabezado

  //estados en la recepción de tramas
  EST_ESPERANDO = 2;   //Estado de espera
  EST_REC_TRAMA = 3;   //Recibiendo una trama

type //=========== Tipo de comandos en la comunicación con las PC cliente. ===========
  {El comando final, puede tomar información adicional, de los parámetros adicionales de
  la trama, como ParamX o ParamY.
  <<<< ADVERTENCIA >>>>:
  * No poner valores de más de 255, porque se ha reservado solo un byte, para almacenar
  este campo.
  Notar que aquí se están juntando los comandos usados tanto para las PC cliente,
  como para los Visores adicionales.
  }
  TCPTipCom = (
    ////////////////////////////////////////////////////////////////////////////////
    //Comandos de control para las PC cliente
    ////////////////////////////////////////////////////////////////////////////////
    //Tipos de Mensajes que incluyen datos. Respuestas a comandos.
    M_PAN_COMP  = $01,  //Mensaje que incluye una pantalla inicial
    M_COORD_RAT = $02,  //Mensaje con coordenadas del raton
    M_PRESENCIA = $03,  //Mensaje de presencia. Sin datos
    M_ESTAD_CLI = $04,  //Mensaje de estado. Indica en que estado se encuentra el servidor

    M_ARC_SOLIC = $06,  //Mensaje que incluye un archivo solicitado

    M_SOL_L_ARC = $09,  //Mensaje con Lista de archivos
    M_SOL_RUT_A = $0A,  //Mensaje con la ruta actual

    M_ARC_SOLIP = $0F,  //Archivo solicitado parcialmente
    M_SOL_VERCL = $14,  //Mensaje con versión del cliente
    M_SOL_NOMPC = $15,  //Mensaje con nombre de la PC
    M_SOL_INFSY = $16,  //Mensaje con información del sistema
    M_SOL_FEHOR = $17,  //Mensaje con información de fecha-hora
    M_SOL_INRED = $18,  //Mensaje con información de red
    M_SOL_LSTDR = $19,  //Mensaje con lista de unidades de disco
    M_SOL_LSTDI = $1A,  //Mensaje con lista de carpetas
    M_SOL_LD_AR = $1B,  //Mensaje con lista detallada de archivos
    M_SOL_CPUME = $1C,  //Mensaje con información de CPU y Memoria

    M_SOL_T_LOC = $26,  //Mensaje tiempos de locutorios

    //---------------------------------------------------------------------
    //Tipos de Comandos permitidos. Los comandos tienen valor >= 128----------
    //---------------------------------------------------------------------
    C_PAN_COMPL = $81,  //Comando de solicitud de pantalla completa
    C_COORD_RAT = $82,  //Comando de solicitud de coordenadas de raton
    C_PRESENCIA = $83,  //Comando de solicitud de presencia

    C_ESTAD_CLI = $84,  //Solicitud de estado del cliente.(APLICABLE A PC CLIENTE)
    C_FIJ_ESCRI = $85,  //Comando para cambiar el escritorio (APLICABLE A PC CLIENTE)
    C_ARC_SOLIC = $86,  //Archivo solicitado (APLICABLE A PC CLIENTE ???)
    C_ARC_ENVIA = $87,  //Comando para enviar archivo
    C_FIJ_ARSAL = $88,  //Fijar nombre de archivo de salida
    C_SOL_L_ARC = $89,  //Solicita lista de archivos de la ruta actual
    C_SOL_RUT_A = $8A,  //Solicita ruta actual
    C_FIJ_RUT_A = $8B,  //Fija la ruta actual
    C_ELI_ARCHI = $8C,  //Elimina el archivo indicado.
    C_EJE_ARCHI = $8D,  //Ejecuta el archivo indicado.
    C_CAN_TRANS = $8E,  //Cancela una transferencia en curso
    C_ARC_SOLIP = $8F,  //Archivo solicitado parcialmente
    C_CRE_CARPE = $90,  //Crea carpeta
    C_ELI_CARPE = $91,  //Elimina carpeta
    C_NOM_ARCHI = $92,  //Cambia nombre a archivo

    C_SOL_VERCL = $94,  //Solicita versión del cliente
    C_SOL_NOMPC = $95,  //Solicita nombre de PC
    C_SOL_INFSY = $96,  //Solicita información de sistema
    C_SOL_FEHOR = $97,  //Solicita fecha hora del sistema
    C_SOL_INRED = $98,  //Solicita información de red
    C_SOL_LSTDR = $99,  //Solicita lista de unidades
    C_SOL_LSTDI = $9A,  //Solicita lista de carpetas
    C_SOL_LD_AR = $9B,  //Solicita lista detallada de archivos
    C_SOL_CPUME = $9C,  //Solicita información de CPU y memoria
    C_SOL_EJBAT = $9D,  //Ejecuta secuencia de comandos por lotes

    C_CHAT_ABRI = $A0,  //Abrir ventana de chat
    C_CHAT_CERR = $A1,  //Cierra ventana de chat
    C_CHAT_MNSJ = $A2,  //Envía mensaje a ventana de chat

    //Comandos cortos que no devuelven mensaje.
    C_BLOQ_PC = $C1,  //Comando de bloqueo de PC
    C_DESB_PC = $C2,  //Comando de desbloqueo de PC
    C_FIJ_RAT = $C3,  //Comando para fijar coordenadas de raton
    C_REIN_PC = $C4,  //Comando para reiniciar PC
    C_MOS_TPO = $C5,  //197-Comando para mostrar tiempo
    C_APAG_PC = $C6,  //Comando para apagar PC
    C_ENCE_PC = $C7,  //Comando para encender PC (WOL)
    C_MENS_PC = $C8,  //Comando de envío de mensaje a PC
    C_GEN_TEC = $C9,  //Comando de generar tecla pulsada
    C_DE_SCSV = $CA,  //Comando para desactivar protector de pantalla
    C_CER_PRO = $CB,  //Comando para cerrar todos los programas
    C_MIN_VEN = $CC,  //Comando para minimizar todas las ventanas
    C_MAX_VEN = $CD,  //Comando para maximizar todas las ventanas
    C_MEN_TIT = $CE,  //Comando para mostrar mensaje en al barra de título

    C_REI_CLI = $D0,  //Comando para reiniciar el cliente
    C_ACT_CLI = $D1,  //Comando para actualizar el programa cliente
    C_REI_COM = $D2,  //Comando para reiniciar el proceso compañero del cliente

    ////////////////////////////////////////////////////////////////////////////////
    //Comandos de control para el Visor o terminal (local o remoto). Se ponen en los
    //valores altos, para poder identificarlos fácilmente.
    ////////////////////////////////////////////////////////////////////////////////
    CVIS_SOLPROP = $E0,  //Solicita archivo de configuración principal (Aplicable a SERVIDOR Y CLIENTE).
    RVIS_SOLPROP = $E1,  //Envía archivo de configuración
    CVIS_SOLESTA = $E2,  //Solicita estado de objetos
    RVIS_SOLESTA = $E3,  //Mensaje con el estado de los objetos
    CVIS_CAPPANT = $E4,  //Solicita captura de pantalla del servidor
    RVIS_CAPPANT = $E5,  //Respuesta a captura de pantalla del servidor
    CVIS_MSJEPC  = $E6,  //Se solicita mostrar un mensaje en la vista.
    CVIS_ACTPROD = $E7,  //Comando Actualizar tabla de productos
    CVIS_ACTPROV = $E8,  //Comando Actualizar tabla de proveedores
    CVIS_ACTINSU = $E9,  //Comando Actualizar tabla de insumos

    C_BD_HISTOR  = $EE,  //Comando a la base de dato histórica
    CVIS_ACBOLET = $EF,  //Acción sobre boleta (Incluye sub-comandos en ParamX)

    CFAC_CABIN = $F0,  //Acción sobre una cabina (Incluye sub-somandos en ParamX)
    RFAC_CABIN = $F1,  //Respuesta de una cabina (Incluye sub-somandos en ParamX)
    CFAC_NILOM = $F2,  //Acciones sobre un NILO-m (Incluye sub-somandos en ParamX)
    CFAC_CLIEN = $F3,  //Acciones sobre un cliente
    CFAC_MESA  = $F4,   //Acciones sobre una mesa

    CFAC_GCABIN = $F8,  //Comando para grupo de Cabinas
    CFAC_GNILOM = $F9,  //Comando para grupo Nilo-M
    CFAC_GMESAS = $FA,  //Comando para grupo de mesas
    CFAC_GCLIEN = $FB,  //Comando para grupo de clientes

    CFAC_G_ELIM = $FC,  //Se solicita eliminar grupo
    CFAC_G_PROP = $FD   //Se solicita fijar propiedades de grupo
  );

type
  { TCPTrama }
  {Objeto que representa a una trama de comunicación del Servidor con las PC cliente.}
  TCPTrama = class
  private
    function GetEncab: string;
    procedure SetEncab(AValue: string);
  public
    //Campos del encabezado
    id_encab: Byte;   //Id del encabezado
    tamDat  : longword; {Tamaño de datos (3 bytes significativos). Este campo es útil para
                         poder reconstruir la trama cuando se recibe.}
    tipTra  : TCPTipCom; //tipo de trama
    posX    : word;    //Posición X (en algunas tramas viene este dato)
    posY    : word;    //Posición Y (en algunas tramas viene este dato)
    //Campos de datos
    traDat  : String;   //parte de los datos de la trama
    //Campos calculados
    property Encab: string read GetEncab write SetEncab;  //encabezado como cadena
    function TipTraNom: string; //Tipo de trama como cadena
    function TipTraHex: string; //Tipo de trama como código hexadecimal
  public
    procedure Assign(desde: TCPTrama);
    procedure Inic(comando: TCPTipCom; ParamX, ParamY: word; cad: string='');
  end;
  TCPTrama_list = specialize TFPGObjectList<TCPTrama>;

  TEvTramaRecibida = procedure of object;  //evento de trama recibida
  TEvRegMensaje = procedure(NomPC: string; msj: string) of object;

  { TCibProcTrama }
  {Procesador de Tramas. Objeto que permite reconstruir las tramas a partir de los
   paquetes recibidos.}
  TCibProcTrama = class
    estad_tra: integer;
    BytesRecib: Integer;
    BytesEsper: Integer;
    trama     : TCPTrama; //trama recibida
    msjErr    : string;   //mensaje de error
    procedure DatosRecibidos(var s: string; ProcesarTrama: TEvTramaRecibida);
  public
    OnRegMensaje  : TEvRegMensaje;   {Para generar un mensaje. Ya que no sabemos si esta
                                     trama, está dentro de un hilo o no.}
    procedure AcumularTrama(dat: string; pos_ini: Longint=0; pos_fin: Longint=0);
    procedure FinTrama;
  public  //Constructor y Destructor
    constructor Create;
    Destructor Destroy; override;
  end;

  { TPilaCom }
  {Modela a una pila LIFO de comandos. Pensada para ser usada en el envío de comandos}
  TPilaCom = class
  private
    items: TCPTrama_list;
  public
    procedure PonerComando(tram: TCPTrama);
    procedure PonerComando(comando: TCPTipCom; ParamX, ParamY: word; cad: string=''
      );
    procedure QuitarComando;
    function HayComando: boolean;
    function PrimerComando: TCPTrama;
  public  //Constructor y destructor
    constructor Create;
    Destructor Destroy; override;
  end;

type //Manejo de la conexión con hilos

  // Estados de una  conexión
  TCibEstadoConex = (
    cecConectando,    //Conectando.
    cecConectado,     //Conectado con socket.
    cecDetenido,      //El proceso se detuvo (no hay control).
    cecMuerto         //Proceso detenido.
  );

  TEvCambiaEstado = procedure(nuevoEstado: TCibEstadoConex) of object;

  TEvTramaLista = procedure(NomPC: string; tram: TCPTrama) of object;

  { TCibConexBase }
  {Clase base que se usa para implementar conexiones con sockets trabajando como hilos.
   Notar que esta clase define a un hilo y debe ser impleemntada como tal.
   Se puede usar tanto para el lado del cliente como para la del servidor. La diferencia
   estaría en cómo se implemente el Execute().}
  TCibConexBase = class(TThread)
  private
    procedure EventoTramaLista;
    procedure EventoCambiaEstado;
    procedure EventoRegMensaje;
  protected
    FEstado   : TCibEstadoConex;
    Sock      : TTCPBlockSocket;
    ProcTrama : TCibProcTrama; //Para procesar tramas
    tmpEstCnx : TCibEstadoConex; //Para pasar parámetro a EventoCambiaEstado()
    tmpRegMsje: string;          //Para pasar parámetro a EventoRegMensaje()
  public  //Eventos y Acciones sincronizadas
    OnRegMensaje : TEvRegMensaje;   //Indica quue desea registrar un mensaje
    OnTramaLista : TEvTramaLista;  //Indica que hay una trama lista esperando
    OnCambiaEstado : TEvCambiaEstado;  //Cambio en estado de la conexión
    procedure SetEstado(AValue: TCibEstadoConex);
    procedure RegMensaje(msje: string);
    procedure ProcTramaRegMensaje(NomPC: string; msj: string);
  public
    property Estado: TCibEstadoConex read FEstado write SetEstado;
    function Conectado: boolean;
    function EstadoConexStr: string;
    procedure ProcesarTrama;
  public
    constructor Create(CreateSuspended: Boolean;
                       const StackSize: SizeUInt = DefaultStackSize);
    Destructor Destroy; override;
  end;

  function GenEncabez(tam: Longint; TipoDato: TCPTipCom; ParamX: word = 0; ParamY: word = 0): string;
  function EstadoConexACadena(estado: TCibEstadoConex): string;
implementation

function GenEncabez(tam: Longint; TipoDato: TCPTipCom; ParamX: word = 0; ParamY: word = 0): string;
//Genera la trama de mensaje de 9 bytes, envía dos parámetros Long
begin
  Result := '         ';  //valor inicial
  //Identificador de mensaje
  Result[1] := chr(ID_ENCABEZ);
  //Envía tamaño de datos (sin considerar el encabezado)
  Result[2] := Chr((tam shr 16) and 255); //mayor peso
  Result[3] := Chr((tam shr 8) and 255);
  Result[4] := Chr(tam and 255);          //menor peso
  //Tipo de dato
  Result[5] := Chr(Byte(TipoDato));
  //Envía parámetros adicionales
  Result[6] := Chr((ParamX shr 8) and 255);
  Result[7] := Chr((ParamX) and 255);
  Result[8] := Chr((ParamY shr 8) and 255);
  Result[9] := Chr((ParamY) and 255);
End;
function EstadoConexACadena(estado: TCibEstadoConex): string;
begin
 case Estado of
 cecConectando : exit('Conectando');
 cecConectado  : exit('Conectado');
 cecDetenido   : exit('Detenido');
 cecMuerto     : exit('Muerto');
 else exit('Desconocido');
 end;
end;

{ TCibConexBase }
//Acciones sincronizadas
procedure TCibConexBase.SetEstado(AValue: TCibEstadoConex);
begin
  if FEstado=AValue then Exit;
  FEstado:=AValue;
  tmpEstCnx := FEstado;
  Synchronize(@EventoCambiaEstado); //dispara evento sicnronizando
end;
procedure TCibConexBase.RegMensaje(msje: string);
{Procedimiento para generar un mensaje dentro del hilo.}
begin
  tmpRegMsje := msje;
  Synchronize(@EventoRegMensaje);
end;
procedure TCibConexBase.ProcTramaRegMensaje(NomPC: string; msj: string);
begin
 //Genera mensajes detallados de la conexión
 tmpRegMsje := msj;
 Synchronize(@EventoRegMensaje);
end;
procedure TCibConexBase.ProcesarTrama;
//Llegó una trama y hay que hacer algo. La trama está en "Encab" y "traDat"
begin
  //Dispara evento sincronizando con proceso padre. Esto puede hacer que deba
  //esperar hasta que haya terminado algún procesamiento.
  Synchronize(@EventoTramaLista);
End;
constructor TCibConexBase.Create(CreateSuspended: Boolean;
  const StackSize: SizeUInt);
begin
 sock := TTCPBlockSocket.create;
 FreeOnTerminate := False;
 ProcTrama:= TCibProcTrama.Create;
 ProcTrama.OnRegMensaje := @ProcTramaRegMensaje;
  inherited Create(CreateSuspended, StackSize);
end;
destructor TCibConexBase.Destroy;
begin
  ProcTrama.Destroy;
  sock.Destroy;
  RegMensaje('Proceso terminado.');
  //estado := cecMuerto;  //No es útil fijar el estado aquí, porque el objeto será destruido
  inherited Destroy;
end;
procedure TCibConexBase.EventoTramaLista;
begin
  if OnTramaLista <> nil then OnTramaLista('', ProcTrama.trama);
end;
procedure TCibConexBase.EventoCambiaEstado;
begin
  if OnCambiaEstado<>nil then OnCambiaEstado(tmpEstCnx);
end;
procedure TCibConexBase.EventoRegMensaje;
begin
  if OnRegMensaje<>nil then OnRegMensaje('', tmpRegMsje);
end;
function TCibConexBase.Conectado: boolean;
begin
  Result := FEstado = cecConectado;
end;
function TCibConexBase.EstadoConexStr: string;
{Convierte TCabEstadoConex a cadena}
begin
 Result := EstadoConexACadena(Festado);
end;

{ TCPTrama }
function TCPTrama.GetEncab: string;
begin
  Result := GenEncabez(tamDat, tipTra, posX, posY);
end;
procedure TCPTrama.SetEncab(AValue: string);
{Lee las propiedades a partir de una cadena. Este método es usado cuando se recibe una
cadena por el socket.}
begin
  id_encab:= ord(AValue[1]);
  tamDat := ord(AValue[2]) * 65536 + ord(AValue[3]) * 256 + ord(AValue[4]);
  tipTra := TCPTipCom(AValue[5]);  //OJO que se convierte de char a TCPTipCom
  //en caso que se indique coordenadas
  posX := ord(AValue[6]) * 256  + ord(AValue[7]);
  posY := ord(AValue[8]) * 256  + ord(AValue[9]);
end;
function TCPTrama.TipTraNom: string;
{Devuelve el tipo de trama como cadena}
begin
  try
    writestr(Result, tipTra);
  except
    Result := '<<Descon>>'
  end;
end;
function TCPTrama.TipTraHex: string;
{Devuelve el tipo de trama como número hexadecimal}
begin
  Result := IntToHex(ord(tipTra), 2);
end;
procedure TCPTrama.Assign(desde: TCPTrama);
{Copia el contenido, desde un objeto similar.}
begin
  id_encab:= desde.id_encab;
  tamDat  := desde.tamDat;
  tipTra  := desde.tipTra;
  posX    := desde.posX;
  posY    := desde.posY;
  traDat  := desde.traDat;
end;
procedure TCPTrama.Inic(comando: TCPTipCom; ParamX, ParamY: word; cad: string='');
{Inicializa la trama con parámetros}
begin
  id_encab:= ID_ENCABEZ;
  tamDat  := length(cad);
  tipTra  := comando;
  posX    := ParamX;
  posY    := ParamY;
  traDat  := cad;
end;
{ TPilaCom }
procedure TPilaCom.PonerComando(tram: TCPTrama);
{Agrega una trama a la cola, que representa a un comando.}
var
  com: TCPTrama;
begin
  com := TCPTrama.Create;  //crea nueva trama
  com.Assign(tram);  //copia valores
  items.Add(com);
end;
procedure TPilaCom.PonerComando(comando: TCPTipCom; ParamX, ParamY: word; cad: string='');
var
  com: TCPTrama;
begin
  com := TCPTrama.Create;  //crea nueva trama
  com.Inic(comando, ParamX, ParamY, cad);
  items.Add(com);
end;
procedure TPilaCom.QuitarComando;
{Quita el comando más antiguo de la cola}
begin
  if not HayComando then exit;
  items.Delete(0);
end;
function TPilaCom.HayComando: boolean;
begin
  Result := items.Count>0;
end;
function TPilaCom.PrimerComando: TCPTrama;
{Devuelve una referencia al primer comando de la pila (el más antiguo)}
begin
  if not HayComando then exit(nil);
  Result := items[0];
end;
//Constructor y destructor
constructor TPilaCom.Create;
begin
  items:= TCPTrama_list.Create(true);
end;
destructor TPilaCom.Destroy;
begin
  items.Destroy;
  inherited Destroy;
end;
{ TCibProcTrama }
procedure TCibProcTrama.AcumularTrama(dat: string; pos_ini: Longint = 0; pos_fin: Longint = 0);
{Agrega los bytes de dat a la "traDat()"
"pos_ini" es la posición inicial donde se encuentran los datos en "dat()"
Si no se especifica se asume que se debe copiar desde el principio.
"pos_fin" es la posición final hasta donde se encuentran los datos en "dat()"
Si no se especifica se asume que se debe copiar hasta el final.
"pos_ini" y "pos_fin" van desde 1 hasta length(dat)}
begin
  If pos_ini = 0 Then
    pos_ini := 1;           //valor por defecto
  If pos_fin = 0 Then
    pos_fin := length(dat); //valor por defecto
  trama.traDat += copy(dat, pos_ini, pos_fin - pos_ini + 1);
End;
procedure TCibProcTrama.FinTrama;
//Se llama al finalizar la recepción de una trama
begin
    estad_tra := EST_ESPERANDO;   //Termina recepción
    BytesRecib := 0;          //Inicia contadores
    BytesEsper := 0;
    trama.traDat := '';             //Inicia la matriz de datos
end;
procedure TCibProcTrama.DatosRecibidos(var s: string; ProcesarTrama: TEvTramaRecibida);
{Procesa un fragmento de trama de datos que ha llegado por el puerto.
 Si se detecta error, en el procesamiento, se devuelve el mensaje en "msjErr".
 Cuando se ha terminado de procesar una trama completa, llama al evento ProcesarTrama().}
{ TODO : Ver si se puede quitar el VAR del parámetro  "s" }
var
  bytesTotal: Integer;
begin
  msjErr := '';
  bytesTotal := length(s);  //bytes que llegan
  if (estad_tra = EST_ESPERANDO) and (ord(s[1]) = ID_ENCABEZ) then begin
    if bytesTotal < 9 then begin
      msjErr := 'Error: Encab. de trama muy pequeño.';
      exit;  //sale
    end;
    trama.Encab := s;   //lee encabezado
    BytesRecib := 0;    //Inicia contador de bytes de datos
    BytesEsper := trama.tamDat;

    //procesa los bytes restantes
    If bytesTotal = TAM_ENCABEZ Then begin   //¿Háy bytes restantes?
      If BytesEsper = 0 Then begin
          //No hay problema, no se esperaban datos
          if ProcesarTrama<>nil then ProcesarTrama;   //Hace algo con la trama que llegó
          FinTrama;
      end Else begin
       //Se esperan datos. Tal vez lleguen en los siguientes paquetes
      End;
    end Else If bytesTotal > TAM_ENCABEZ Then begin
      BytesRecib := bytesTotal - TAM_ENCABEZ;
      //Hay más bytes que procesar
      If BytesRecib = BytesEsper Then begin
        //Toda la trama vino en un sólo paquete
//                Plog "Trama completa llegó en paquete"
        AcumularTrama(s, TAM_ENCABEZ+1);
        if ProcesarTrama<>nil then ProcesarTrama;   //Hace algo con la trama que llegó
        FinTrama;
      end Else If BytesRecib < BytesEsper Then begin
        //Parte de los datos llegarán en otro(s) paquete
        if OnRegMensaje<>nil then
          OnRegMensaje('', '-Se esperan otros paquetes para completar trama');
        AcumularTrama(s, TAM_ENCABEZ+1);
        estad_tra := EST_REC_TRAMA;   //pone en estado de recepción
      end Else begin
        //Están llegando más de una trama en un solo paquete
        AcumularTrama(s, TAM_ENCABEZ+1, TAM_ENCABEZ + BytesEsper); //toma solo los de la primera trama
        if ProcesarTrama<>nil then ProcesarTrama;   //la procesa
        delete(s,1, TAM_ENCABEZ + BytesEsper);  //quita datos de la primera trama
        FinTrama;        //termina el procesamiento
        //Llama recursivamente para procesar siguientes tramas
        DatosRecibidos(s, ProcesarTrama);   //puede salir con error
        exit;
      End;
    End;
  end else begin
    //Otro paquete que contiene datos de una trama anterior o puede ser basura
    If BytesEsper = 0 Then begin  //No se esperaba este paquete
      //No se toma ninguna acción. Se ignora
      if OnRegMensaje<>nil then begin
        OnRegMensaje('', '-Paquete no esperado de ' + IntToStr(bytesTotal) + ' bytes (' +
                         IntToStr(estad_tra) + ':' + IntToStr(Ord(s[1])) +').');
      end;
      //Debería verificarse si corresponde al inicio de otra trama
      //Si es que ha habido error al transmitir los paquetes anteriores
      //    If datos(0) = ID_ENCABEZ Then
    end Else begin       //Hay más paquetes esperados
      //Verificamos el tamaño del paquete
      BytesRecib += bytesTotal;   //Actualiza contador
//          Log "Llegó paquete de " & bytesTotal & " bytes. Acumulados: " & BytesRecib
      If BytesRecib = BytesEsper Then begin
        if OnRegMensaje<>nil then
          OnRegMensaje('', '-Trama completada con este paquete');
        AcumularTrama(s);
        if ProcesarTrama<>nil then ProcesarTrama;
        FinTrama;
      end Else If BytesRecib < BytesEsper Then begin
        //Todavía hay más paquetes de la trama que deben llegar
        if OnRegMensaje<>nil then
          OnRegMensaje('', '-Acumulando paquetes de trama: ' + IntToStr(BytesRecib)+
                           '/' + IntToStr(BytesEsper) + ' bytes.');
//        Plog "Acumulando paquetes para completar trama: " & BytesRecib
        AcumularTrama(s);
      end Else begin
        //Está llegando lo que falta de la trama anterior y probablemente
        //el inicio de otra trama
//          Plog "Trama completada, pero hay mas bytes en paquete"
        //copia sólo lo que falta para completar los datos
        AcumularTrama(s, 0, bytesTotal - (BytesRecib - BytesEsper) );
        if ProcesarTrama<>nil then ProcesarTrama;
        delete(s,1, bytesTotal - (BytesRecib - BytesEsper));  //quita datos de la primera trama
        FinTrama;
        //Llama recursivamente para procesar siguientes tramas
        DatosRecibidos(s, ProcesarTrama);   //puede salir con error
        exit;
      End;
    End;
  end;
end;
//Constructor y Destructor
constructor TCibProcTrama.Create;
begin
  trama  := TCPTrama.Create;
  FinTrama();  //Inicia recepción
end;
destructor TCibProcTrama.Destroy;
begin
  trama.Destroy;
  inherited Destroy;
end;

end.

