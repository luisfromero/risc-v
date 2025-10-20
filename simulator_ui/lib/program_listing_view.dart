import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'datapath_state.dart';

/// Un widget que muestra el listado estático del programa cargado en memoria,
/// permitiendo la interacción para establecer breakpoints.
class ProgramListingView extends StatefulWidget {
  const ProgramListingView({super.key});

  @override
  State<ProgramListingView> createState() => _ProgramListingViewState();
}

class _ProgramListingViewState extends State<ProgramListingView> {
  final ScrollController _scrollController = ScrollController();

  // Es importante liberar el controlador cuando el widget se destruye.
  @override
  Widget build(BuildContext context) {
    // Escuchamos a DatapathState para obtener la memoria de instrucciones y el PC actual.
    final datapathState = Provider.of<DatapathState>(context);

    if (datapathState.instructionMemory == null) {
      return const Center(child: Text('No program loaded.'));
    }

    // --- Lógica de Auto-Scroll ---
    // Se ejecuta después de que el frame se ha renderizado para asegurar que el
    // scrollController está listo y las dimensiones son conocidas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final instructionList = datapathState.instructionMemory!;
      final currentPc = datapathState.current_pc;

      // Buscamos el índice de la instrucción actual.
      final index = instructionList.indexWhere((item) => item.address == currentPc);

      if (index != -1) {
        // Estimamos la altura de cada elemento para calcular el desplazamiento.
        // (Padding vertical de 2+2, más la altura de la fuente).
        const double itemHeight = 18.0; 
        final targetOffset = index * itemHeight;

        // Obtenemos el área visible actual del ListView.
        final minScroll = _scrollController.position.pixels;
        final maxScroll = minScroll + _scrollController.position.viewportDimension;

        // Si el elemento no está visible, lo centramos.
        if (targetOffset < minScroll || targetOffset > maxScroll - itemHeight) {
          final centeredOffset = targetOffset - (_scrollController.position.viewportDimension / 2) + (itemHeight / 2);
          _scrollController.animateTo(
            centeredOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: datapathState.instructionMemory!.length,
      itemBuilder: (context, index) {
        final item = datapathState.instructionMemory![index];
        final isCurrentPc = item.address == datapathState.current_pc;
        final hasBreakpoint = datapathState.hasBreakpoint(item.address);

        return InkWell( // Hace que la fila sea clicable.
          onTap: () => datapathState.toggleBreakpoint(item.address),
          child: Container(
            color: isCurrentPc ? Colors.yellow.shade200 : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // Indicador visual del breakpoint.
                SizedBox(width: 16, child: hasBreakpoint ? const Icon(Icons.circle, color: Colors.red, size: 10) : null),
                // Texto de la instrucción.
                Expanded(child: Text('${toHex(item.address, 4, true)}: ${item.instruction}', style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily: 'RobotoMono'))),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}