
import 'dart:core';

// --- Desplazamientos Globales ---

// --- Posiciones de los Componentes ---

// Unidad de Control
const double widthUC = 1120;
const double heightUC = 60;





// Permiten mover todo el datapath sin cambiar cada coordenada individualmente.
const double y_shift=heightUC;
const double x_shift=20;


const double yPosUC =0;
const double xPosUC=x_shift+150;


// Parámetros principales y eje central
const double h_main=120;
const double y_main=y_shift+260;

// Referencias buses

const double yPc4Up =y_shift+ 65;
const double yNPC=y_shift+ 80;
const double yAluResultUp=y_shift+ 175;
const double y_Bdown=y_shift+330;
const double yAlu2pcDown=y_shift+480;
const double yBrDown=y_shift+500;
const double yWbDown=y_shift+520;

//const double xCimm=xShift+ 1340;
const double xPcUp=x_shift+ 190; //pc_bus vertical

const double xMinimo=x_shift+0;
const double xMinimo2=x_shift+20;

//const double xRegOut=xShift+770;
//const double xImmOut=xShift+790;

const double x_B_mem=x_shift+965;

const double x_4=x_shift+ 500; //Salida a BR, antes de llegar
const double x_5=x_shift+ 1150; //Bus a M1
const double x_6=x_shift+ 1165; //Bus a M1
const double xMaximo=x_shift+ 1260; //Bus C 
//const double xMaximo=xShift+ 1390; //Bus PC destC 
const double x_PipeDCfinal=x_shift+480;
const double x_PipeDCinicial=x_shift+460;

const x_dcPipe1=x_shift+450;
const x_dcPipe2=x_shift+1160;


const double yCimm=y_shift+510; //Control inmediato
const double yCpcSrc=y_shift+30;
const double y_PipeDCfinal=y_shift+490;
const y_rdest=y_shift+345; //Buses de propagacion de registro destino

const double yInstrucciones=y_shift+540;
const double xDerecha=xMaximo+20;


// Referencias buses control Pipelie
const double x_controlPipe_Pcsrc=x_shift+670;


// Tamaños compartidos

const double widthReg=10;
const double heightIB=260;

const double widthPC = 30;
const double heightPC = h_main;

//Estos dos no los estoy usando. Revisar
const double widthAdder = 80;
const double heightAdder = 60;

const double widthMuxFwd = 20;
const double heightMuxFwd = 40;

const double widthIB = 40;

const double heightNPCReg=40;
const double heightPCPipeReg=40;

// PC y componentes asociados

const double xMuxPC =x_shift+ 30;
const double yMuxPC = y_main-h_MainMuxes/2;

const double xPC = x_shift+130;
const double yPC = y_main-heightPC/2;

const double xAdderPC =x_shift+ 220;
const double yAdderPC = y_shift + 90;

const double xConst4 = x_shift+50;
const double yConst4 = y_shift + 110;

// Etapa IF (Instruction Fetch)

const double xInstrMem =x_shift+ 280;
const double yInstrMem = y_main- heightMems/2;

// Registros de Pipeline IF/ID
const double xIB = x_shift+ 420;
const double yIB = y_shift + 160;
const double xPipeRegIFID_NPC =xIB;
const double yPipeRegIFID_NPC = yIB-heightNPCReg;
const double xPipeRegIFID_PC =xIB;
const double yPipeRegIFID_PC =yIB+heightIB;

// Etapa ID (Instruction Decode)
const double widthMems=80; 
const double heightMems=h_main;
const double xRegFile =x_shift+ 520;
const double yRegFile = y_main- heightMems/2;

const double widthExtender=100;
const double heightExtender=30;
const double xExtender = x_shift+ 520;

// Registros de Pipeline ID/EX

const double xPipeRegIDEX_Control = x_shift+640;
const double yPipeRegIDEX_Control = y_shift + 80;

const double xPipeRegIDEX_NPC = x_shift+640;
const double yPipeRegIDEX_NPC = y_shift + 120; 

const double xPipeRegIDEX_Data =x_shift+ 640; // A, B, Imm, etc.
const double yPipeRegIDEX_Data = y_shift + 160;

const double xPipeRegIDEX_PC =x_shift+ 640;
const double yPipeRegIDEX_PC = y_shift + 420;

// Etapa EX (Execute)

const double widthMuxALU=30;
const double heightMuxALU=50;
const double xMuxALU =x_shift+ 710;
const double yMuxALU = y_shift + 265;

const double widthALU = 60;
const double heightALU = h_main;

const double w_mainMuxes = 40;
const double h_MainMuxes = 80;

const double xAdderBranch =x_shift+ 710;
const double yAdderBranch = y_shift + 350;

const double xALU =x_shift+ 820;
const double yALU = y_main-heightALU/2;

const double xFlagZ =x_shift+ 900;

// Se calculaconst double yFlagZ = yShift + 220;


// Unidades de Riesgo (Hazard Units)

const double widthHazard=100;
const double heightHazard=50;
const double xHazardUnits =x_shift+ 750;
const double yHazardUnits = y_shift + 10;

// Muxes de Forwarding
const double xMuxFwdA =xALU-40;
const double yMuxFwdA = y_shift + 210;

const double xMuxFwdB =xALU-40;
const double yMuxFwdB = y_shift + 270;

const double xMuxFwdM =xDataMem-40;
const double yMuxFwdM = y_shift + 270;


// Registros de Pipeline EX/MEM
const double xPipeRegEXMEM_Control =x_shift+ 920;
const double yPipeRegEXMEM_Control = y_shift + 80;

const double xPipeRegEXMEM_NPC = x_shift+920;
const double yPipeRegEXMEM_NPC = y_shift + 120;

const double xPipeRegEXMEM_Data =x_shift+ 920;
const double yPipeRegEXMEM_Data = y_shift + 160;

// Etapa MEM (Memory)
const double xDataMem =x_shift+ 1020;
const double yDataMem = y_main-heightALU/2;

// Registros de Pipeline MEM/WB
const double xPipeRegMEMWB_Control =x_shift+ 1120;
const double yPipeRegMEMWB_Control = y_shift + 80;

const double xPipeRegMEMWB_NPC = x_shift+1120;
const double yPipeRegMEMWB_NPC = y_shift + 120;

const double xPipeRegMEMWB_Data =x_shift+ 1120;
const double yPipeRegMEMWB_Data = y_shift + 160;

// Etapa WB (Write Back)
const double xMuxWB =x_shift+ 1180;
const double yMuxWB = y_main-h_MainMuxes/2;

const double y_controlWrite=y_shift+115;



const double heightControlPipe1=30;
const double heightControlPipe2=20;
const double heightControlPipe3=10;

const double xInstruction =x_shift+740;
const double xInstructionD =x_shift+330;

const double xInstruction1 =x_shift+160;
const double xInstruction2 =x_shift+400;
const double xInstruction3 =x_shift+640;
const double xInstruction4 =x_shift+900;
const double xInstruction5 =x_shift+1120;

//Connection points de la UC relativos a los buses 

//dependen algunos de los orígenes


//Valores derivados

const double yPipePC0=yAdderBranch+0.25*heightALU; //y del extensor de imm
const double yPipePC1=yAdderBranch+0.75*heightALU; //y de la propagacion del pc

//El extensor depende del Branch @
const double yExtender = yPipePC0 -heightExtender*0.5;

//La salida B del BR  depende del muxB, arriba (290)
const y_BR_B=yMuxALU+0.25*heightMuxALU;
const r_BR_B=(y_BR_B-yRegFile)/heightMems;





//x de los buses que salen de la UC
const double xControl1=380; //ok
const double xControl2=500; //ok
const double xControl3=560; //funct3
const double xControl4=600; //funct7
const double xControl5=xRegFile+0.5*widthMems; // 
const double xControl6=xMuxALU+0.35*widthMuxALU; //
const double xControl7=xALU+0.5*widthALU; //
const double xControl8=xFlagZ; //ok flagZ
const double xControl9=xDataMem+0.5*widthMems; //
const double xControl10=xMuxWB+0.35*w_mainMuxes; //
const double xControl11=xPosUC+widthUC-20; //ok



const ucx1=(xControl1-xPosUC )/widthUC;
const ucx2=(xControl2-xPosUC )/widthUC;
const ucx3=(xControl3-xPosUC )/widthUC;
const ucx4=(xControl4-xPosUC )/widthUC;
const ucx5=(xControl5-xPosUC )/widthUC;
const ucx6=(xControl6-xPosUC )/widthUC;
const ucx7=(xControl7-xPosUC )/widthUC;
const ucx8=(xControl8-xPosUC )/widthUC;
const ucx9=(xControl9-xPosUC )/widthUC;
const ucx10=(xControl10-xPosUC )/widthUC;
const ucx11=(xControl11-xPosUC )/widthUC;

// Parametros del Banco de registros para usar en IB

const yIr0=yRegFile+0.2*heightMems;
const yIr1=yRegFile+0.4*heightMems;
const yIr2=yRegFile+0.6*heightMems;
const yIr3=yRegFile+0.8*heightMems;

const yImm0=yExtender+0.5*heightExtender;

const r_IB0=0.385;  //Entrada instruccion
const r_IB1=0.03; //Salida Opcode
const r_IB2=0.08; //funct3
const r_IB3=0.13; //funct7  



const r_IB4=(yIr0-yIB)/heightIB;
const r_IB5=(yIr1-yIB)/heightIB;
const r_IB6=(yIr2-yIB)/heightIB;
const r_IB7=(yImm0-yIB)/heightIB;


// Las entradas y salidas del registro ID/EX dependen del banco de registros.

const double ytmp0=yRegFile+0.25*heightMems;  //A  


const r_DE0=(ytmp0-yPipeRegIDEX_Data)/heightIB;
const r_DE1=(y_BR_B-yPipeRegIDEX_Data)/heightIB;
const r_DE2=(y_rdest-yPipeRegIDEX_Data)/heightIB;
const r_DE3=(yPipePC0-yPipeRegIDEX_Data)/heightIB;
const r_DE4=0.1;


const double yFlagZ=yALU+0.25*heightALU; //flagZ (no se usa, pero por si)
const double y_salidaALU=yALU+0.5*heightALU;  //Salida ALU 


const r_EM0=(yFlagZ-yPipeRegEXMEM_Data)/heightIB;
const r_EM1=(y_salidaALU-yPipeRegEXMEM_Data)/heightIB;
const r_EM2=(y_Bdown-yPipeRegEXMEM_Data)/heightIB;
const r_EM3=(y_rdest-yPipeRegEXMEM_Data)/heightIB;

const double ySalidaMemData=yMuxWB +0.6*h_MainMuxes; //La referencia es la entrada 2 del mux (60%)y deberia usarse para el calculo de la salida de la memoria de datos

const double ry_salidaMemData=(ySalidaMemData-yDataMem)/heightMems;



const r_MW0 =(yAluResultUp-yPipeRegMEMWB_Data)/heightIB;
const r_MW1 =(ySalidaMemData-yPipeRegMEMWB_Data)/heightIB;  //La referencia es la entrada 2 del mux
const r_MW2 =(y_rdest-yPipeRegMEMWB_Data)/heightIB;


//Lo mismo para NPC

const double yPipeNPC1=(yAdderPC+0.5*heightALU-yPipeRegIDEX_NPC)/heightNPCReg;

// Y para los pc del pipe


const double rPipePC1=(yPipePC1-yPipeRegIDEX_PC)/heightPCPipeReg;  //No se usa porque sale 0.5 pero se debería usar

//
const double yFwdA=y_shift+355;
const double yFwdB=y_shift+365;

const double xFwdMem=xMuxFwdA-20;
const double xFwdWr=xFwdMem-10;

const double yMuxFwdA0=yMuxFwdA+0.25*heightMuxFwd;
const double yMuxFwdB0=yMuxFwdB+0.25*heightMuxFwd;
const double yMuxFwdA1=yMuxFwdA+0.75*heightMuxFwd;
const double yMuxFwdB1=yMuxFwdB+0.75*heightMuxFwd;
const double yMuxFwdM0=yMuxFwdM+0.75*heightMuxFwd;
const double yMuxFwdM1=yMuxFwdM+0.75*heightMuxFwd;


// Calculamos la x de los buses que activan los muxes de los cortocircuitos
const double x_controlMuxHzd=xMuxFwdA+0.3*widthMuxFwd;
const double rx_controlMuxHzd=(x_controlMuxHzd- xHazardUnits)/widthHazard;