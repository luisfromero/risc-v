
import 'dart:core';

// --- Desplazamientos Globales ---

// --- Posiciones de los Componentes ---

// Unidad de Control
const double widthUC = 1100;
const double heightUC = 70;

// Permiten mover todo el datapath sin cambiar cada coordenada individualmente.
const double yShift=heightUC;
const double xShift=0;

const double yPosUC =0;
const double xPosUC=xShift+275;


// Referencias buses

const double yPc4Up =yShift+ 65;
const double yNPC=yShift+ 80;
const double yAluResultUp=yShift+ 175;
const double y_Bdown=yShift+330;
const double yAlu2pcDown=yShift+480;
const double yBrDown=yShift+500;
const double yWbDown=yShift+520;

//const double xCimm=xShift+ 1340;
const double xPcUp=xShift+ 290; //pc_bus vertical
const double xMinimo=xShift+20;
const double xMinimo2=xShift+40;
//const double xRegOut=xShift+770;
//const double xImmOut=xShift+790;

const double x_B_mem=xShift+1080;

const double x_4=xShift+ 600; //Salida a BR, antes de llegar
const double x_5=xShift+ 1250; //Bus a M1
const double x_6=xShift+ 1265; //Bus a M1
const double xMaximo=xShift+ 1360; //Bus C 
//const double xMaximo=xShift+ 1390; //Bus PC destC 
const double x_PipeDCfinal=xShift+580;
const double x_PipeDCinicial=xShift+560;

const x_dcPipe1=xShift+550;
const x_dcPipe2=xShift+1260;


const double yCimm=yShift+510; //Control inmediato
const double yCpcSrc=yShift+30;
const double y_PipeDCfinal=yShift+490;
const y_rdest=yShift+345; //Buses de propagacion de registro destino

const double yInstrucciones=yShift+540;
const double xDerecha=xMaximo+20;


// Referencias buses control Pipelie
const double x_controlPipe_Pcsrc=xShift+770;


// Tamaños compartidos

const double widthReg=10;
const double heightIB=260;

const double widthPC = 30;
const double heightPC = 120;

//Estos dos no los estoy usando. Revisar
const double widthAdder = 80;
const double heightAdder = 60;

const double widthMuxFwd = 20;
const double heightMuxFwd = 40;

const double widthIB = 40;

const double heightNPCReg=40;
const double heightPCPipeReg=40;

// PC y componentes asociados

const double xMuxPC =xShift+ 60;
const double yMuxPC = yShift + 220;

const double xPC = xShift+230;
const double yPC = yShift + 200;

const double xAdderPC =xShift+ 320;
const double yAdderPC = yShift + 90;

const double xConst4 = xShift+150;
const double yConst4 = yShift + 110;

// Etapa IF (Instruction Fetch)

const double xInstrMem =xShift+ 380;
const double yInstrMem = yShift + 200;

// Registros de Pipeline IF/ID
const double xIB = xShift+ 520;
const double yIB = yShift + 160;
const double xPipeRegIFID_NPC =xIB;
const double yPipeRegIFID_NPC = yIB-heightNPCReg;
const double xPipeRegIFID_PC =xIB;
const double yPipeRegIFID_PC =yIB+heightIB;

// Etapa ID (Instruction Decode)
const double widthMems=80; 
const double heightMems=120;
const double xRegFile =xShift+ 620;
const double yRegFile = yShift + 200;

const double widthExtender=100;
const double heightExtender=30;
const double xExtender = xShift+ 620;

// Registros de Pipeline ID/EX

const double xPipeRegIDEX_Control = xShift+740;
const double yPipeRegIDEX_Control = yShift + 80;

const double xPipeRegIDEX_NPC = xShift+740;
const double yPipeRegIDEX_NPC = yShift + 120; 

const double xPipeRegIDEX_Data =xShift+ 740; // A, B, Imm, etc.
const double yPipeRegIDEX_Data = yShift + 160;

const double xPipeRegIDEX_PC =xShift+ 740;
const double yPipeRegIDEX_PC = yShift + 420;

// Etapa EX (Execute)

const double widthMuxALU=30;
const double heightMuxALU=50;
const double xMuxALU =xShift+ 810;
const double yMuxALU = yShift + 265;

const double widthALU = 60;
const double heightALU = 120;

const double widthMuxWB = 40;
const double heightMuxWB = 80;

const double xAdderBranch =xShift+ 810;
const double yAdderBranch = yShift + 350;

const double xALU =xShift+ 920;
const double yALU = yShift + 200;

const double xFlagZ =xShift+ 1040;

// Se calculaconst double yFlagZ = yShift + 220;


// Unidades de Riesgo (Hazard Units)

const double widthHazard=100;
const double heightHazard=50;
const double xHazardUnits =xShift+ 850;
const double yHazardUnits = yShift + 10;

// Muxes de Forwarding
const double xMuxFwdA =xShift+ 880;
const double yMuxFwdA = yShift + 210;

const double xMuxFwdB =xShift+ 880;
const double yMuxFwdB = yShift + 270;

// Registros de Pipeline EX/MEM
const double xPipeRegEXMEM_Control =xShift+ 1020;
const double yPipeRegEXMEM_Control = yShift + 80;

const double xPipeRegEXMEM_NPC = xShift+1020;
const double yPipeRegEXMEM_NPC = yShift + 120;

const double xPipeRegEXMEM_Data =xShift+ 1020;
const double yPipeRegEXMEM_Data = yShift + 160;

// Etapa MEM (Memory)
const double xDataMem =xShift+ 1100;
const double yDataMem = yShift + 200;

// Registros de Pipeline MEM/WB
const double xPipeRegMEMWB_Control =xShift+ 1220;
const double yPipeRegMEMWB_Control = yShift + 80;

const double xPipeRegMEMWB_NPC = xShift+1220;
const double yPipeRegMEMWB_NPC = yShift + 120;

const double xPipeRegMEMWB_Data =xShift+ 1220;
const double yPipeRegMEMWB_Data = yShift + 160;

// Etapa WB (Write Back)
const double xMuxWB =xShift+ 1280;
const double yMuxWB = yShift + 220;

const double y_controlWrite=yShift+115;



const double heightControlPipe1=30;
const double heightControlPipe2=20;
const double heightControlPipe3=10;

const double xInstruction =xShift+840;
const double xInstructionD =xShift+430;

const double xInstruction1 =xShift+240;
const double xInstruction2 =xShift+500;
const double xInstruction3 =xShift+750;
const double xInstruction4 =xShift+1010;
const double xInstruction5 =xShift+1230;

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
const double xControl2=460; //ok
const double xControl3=560; //funct3
const double xControl4=600; //funct7
const double xControl5=xRegFile+0.5*widthMems; // 
const double xControl6=xMuxALU+0.35*widthMuxALU; //
const double xControl7=xALU+0.5*widthALU; //
const double xControl8=1000; //ok flagZ
const double xControl9=xDataMem+0.5*widthMems; //
const double xControl10=xMuxWB+0.35*widthMuxWB; //
const double xControl11=xPosUC+1070; //ok



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


const double yFlagZ=yALU+0.35*heightALU; //flagZ (no se usa, pero por si)
const double y_salidaALU=yALU+0.5*heightALU;  //Salida ALU 


const r_EM0=(yFlagZ-yPipeRegEXMEM_Data)/heightIB;
const r_EM1=(y_salidaALU-yPipeRegEXMEM_Data)/heightIB;
const r_EM2=(y_Bdown-yPipeRegEXMEM_Data)/heightIB;
const r_EM3=(y_rdest-yPipeRegEXMEM_Data)/heightIB;

const double ySalidaMemData=yMuxWB +0.6*heightMuxWB; //La referencia es la entrada 2 del mux (60%)y deberia usarse para el calculo de la salida de la memoria de datos

const double ry_salidaMemData=(ySalidaMemData-yDataMem)/heightMems;



const r_MW0 =(yAluResultUp-yPipeRegMEMWB_Data)/heightIB;
const r_MW1 =(ySalidaMemData-yPipeRegMEMWB_Data)/heightIB;  //La referencia es la entrada 2 del mux
const r_MW2 =(y_rdest-yPipeRegMEMWB_Data)/heightIB;


//Lo mismo para NPC

const double yPipeNPC1=(yAdderPC+0.5*heightALU-yPipeRegIDEX_NPC)/heightNPCReg;

// Y para los pc del pipe


const double rPipePC1=(yPipePC1-yPipeRegIDEX_PC)/heightPCPipeReg;  //No se usa porque sale 0.5 pero se debería usar

//
const double yFwdA=yShift+355;
const double yFwdB=yShift+365;
const double xFwdMem=xShift+862;
const double xFwdWr=xShift+855;

const double yMuxFwdA0=yMuxFwdA+0.25*heightMuxFwd;
const double yMuxFwdB0=yMuxFwdB+0.25*heightMuxFwd;
const double yMuxFwdA1=yMuxFwdA+0.75*heightMuxFwd;
const double yMuxFwdB1=yMuxFwdB+0.75*heightMuxFwd;


// Calculamos la x de los buses que activan los muxes de los cortocircuitos
const double x_controlMuxHzd=xMuxFwdA+0.3*widthMuxFwd;
const double rx_controlMuxHzd=(x_controlMuxHzd- xHazardUnits)/widthHazard;