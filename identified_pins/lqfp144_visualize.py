import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as patches


def plot_lqfp144(
    csv_path="gowin_ar_lv18e1144pc.csv",
    output_path="lqfp144_pinout.png"
):

    # ============================================================
    # 1. CARGAR Y LIMPIAR LOS DATOS DEL CSV
    # ============================================================

    df = pd.read_csv(csv_path)

    # Limpiar nombres de columnas
    df.columns = df.columns.str.strip().str.rstrip(';')

    # Mapear los datos de cada pin indexados por número
    pin_data = {}

    for _, row in df.iterrows():
        try:
            p_num = int(row['FPGA Pin Number'])
            p_name = str(row.get('Pin Name', '')).strip()
            p_conn = str(row.get('Connected To', '')).strip().rstrip(';')
            p_func = str(row.get('Function', '')).strip()

            pin_data[p_num] = {
                'name': p_name,
                'conn': p_conn,
                'func': p_func
            }

        except (ValueError, KeyError):
            continue

    # ============================================================
    # 2. PINES CONOCIDOS AGREGADOS MANUALMENTE
    # ============================================================

    manual_pins = {

        # Controles direccionales
        99: {
            'name': 'FPGA Pin 99',
            'conn': 'RIGHT',
            'func': 'I/O'
        },

        100: {
            'name': 'FPGA Pin 100',
            'conn': 'DOWN',
            'func': 'I/O'
        },

        101: {
            'name': 'FPGA Pin 101',
            'conn': 'UP',
            'func': 'I/O'
        },

        102: {
            'name': 'FPGA Pin 102',
            'conn': 'LEFT',
            'func': 'I/O'
        },

        # Botones A y B
        51: {
            'name': 'FPGA Pin 51',
            'conn': 'A',
            'func': 'I/O'
        },

        50: {
            'name': 'FPGA Pin 50',
            'conn': 'B',
            'func': 'I/O'
        },

        # START / SELECT
        97: {
            'name': 'FPGA Pin 97',
            'conn': 'START',
            'func': 'I/O'
        },

        98: {
            'name': 'FPGA Pin 98',
            'conn': 'SELECT',
            'func': 'I/O'
        }
    }

    # Agregar los pines manuales
    pin_data.update(manual_pins)

    # ============================================================
    # 3. CONFIGURAR LA FIGURA
    # ============================================================

    fig, ax = plt.subplots(figsize=(22, 22), dpi=150)

    bg_color = '#11151c'

    fig.patch.set_facecolor(bg_color)
    ax.set_facecolor(bg_color)

    # ============================================================
    # 4. PARÁMETROS DEL LQFP-144
    # ============================================================

    body_size = 42.0
    half_body = body_size / 2.0

    lead_length = 3.6
    lead_width = 0.58

    pins_per_side = 36

    # ============================================================
    # 5. CUERPO DEL FPGA
    # ============================================================

    ic_body = patches.FancyBboxPatch(
        (-half_body, -half_body),
        body_size,
        body_size,
        boxstyle="round,pad=0.2,rounding_size=1.2",
        linewidth=1.8,
        edgecolor='#3b4252',
        facecolor='#1e222b',
        zorder=2
    )

    ax.add_patch(ic_body)

    # ============================================================
    # 6. INDICADOR DEL PIN 1
    # ============================================================

    pin1_dot = patches.Circle(
        (-half_body + 3.2, half_body - 3.2),
        radius=1.1,
        facecolor='#4c566a',
        edgecolor='#88c0d0',
        linewidth=1.5,
        zorder=3
    )

    ax.add_patch(pin1_dot)

    # ============================================================
    # 7. TEXTOS CENTRALES
    # ============================================================

    ax.text(
        0, 3.5,
        "LQFP-144",
        color='#eceff4',
        fontsize=24,
        fontweight='bold',
        ha='center',
        va='center',
        zorder=3
    )

    ax.text(
        0, 0.0,
        "GOWIN FPGA",
        color='#88c0d0',
        fontsize=17,
        fontweight='semibold',
        ha='center',
        va='center',
        zorder=3
    )

    ax.text(
        0, -3.2,
        "GW1N / AR_LV18E1144PC",
        color='#d8dee9',
        fontsize=13,
        ha='center',
        va='center',
        zorder=3
    )

    ax.text(
        0, -6.5,
        f"Pines conectados: {len(pin_data)} / 144",
        color='#a3be8c',
        fontsize=12,
        ha='center',
        va='center',
        zorder=3
    )

    # ============================================================
    # 8. COORDENADAS DE LOS PINES
    # ============================================================

    span = half_body - 2.6

    step = (2 * span) / (pins_per_side - 1)

    coords = [
        span - i * step
        for i in range(pins_per_side)
    ]

    # ============================================================
    # 9. DIBUJAR LOS 144 PINES
    # ============================================================

    for pin_num in range(1, 145):

        is_conn = pin_num in pin_data

        info = pin_data.get(pin_num, None)

        # --------------------------------------------------------
        # COLORES
        # --------------------------------------------------------

        if is_conn:

            func = info['func'].lower()
            name_lower = info['name'].lower()
            conn_lower = info['conn'].lower()

            # Alimentación
            if (
                'power' in func
                or 'vcc' in name_lower
                or 'gnd' in name_lower
            ):

                lead_color = '#bf616a'
                label_color = '#ff8b94'

            # JTAG
            elif (
                'jtag' in conn_lower
                or 'mcu' in conn_lower
                or any(
                    j in name_lower
                    for j in ['tms', 'tck', 'tdi', 'tdo']
                )
            ):

                lead_color = '#ebcb8b'
                label_color = '#ffea79'

            # I2C / EEPROM
            elif (
                'eeprom' in conn_lower
                or 'i2c' in conn_lower
                or 'scl' in name_lower
                or 'sda' in name_lower
            ):

                lead_color = '#a3be8c'
                label_color = '#b8e994'

            # I/O general
            else:

                lead_color = '#88c0d0'
                label_color = '#88e1f2'

            # Texto de etiqueta
            label = (
                f"{info['conn']} ({info['name']})"
                if info['conn']
                else info['name']
            )

        else:

            # Pines no utilizados
            lead_color = '#383f4d'
            label_color = '#5d677a'

            label = ""

        # ========================================================
        # LADO IZQUIERDO: PINES 1 - 36
        # ========================================================

        if 1 <= pin_num <= 36:

            idx = pin_num - 1

            y = coords[idx]

            x_body = -half_body

            lead = patches.Rectangle(
                (
                    x_body - lead_length,
                    y - lead_width / 2
                ),
                lead_length,
                lead_width,
                facecolor=lead_color,
                edgecolor='#1b1f27',
                lw=0.4,
                zorder=2
            )

            ax.add_patch(lead)

            ax.text(
                x_body + 0.8,
                y,
                str(pin_num),
                color='#d8dee9',
                fontsize=6.5,
                ha='left',
                va='center',
                fontweight='bold',
                zorder=4
            )

            if is_conn:

                ax.text(
                    x_body - lead_length - 0.7,
                    y,
                    label,
                    color=label_color,
                    fontsize=7.5,
                    fontweight='bold',
                    ha='right',
                    va='center',
                    zorder=4
                )

        # ========================================================
        # LADO INFERIOR: PINES 37 - 72
        # ========================================================

        elif 37 <= pin_num <= 72:

            idx = pin_num - 37

            x = -coords[idx]

            y_body = -half_body

            lead = patches.Rectangle(
                (
                    x - lead_width / 2,
                    y_body - lead_length
                ),
                lead_width,
                lead_length,
                facecolor=lead_color,
                edgecolor='#1b1f27',
                lw=0.4,
                zorder=2
            )

            ax.add_patch(lead)

            ax.text(
                x,
                y_body + 0.8,
                str(pin_num),
                color='#d8dee9',
                fontsize=6.5,
                ha='center',
                va='bottom',
                fontweight='bold',
                rotation=90,
                zorder=4
            )

            if is_conn:

                ax.text(
                    x,
                    y_body - lead_length - 0.7,
                    label,
                    color=label_color,
                    fontsize=7.5,
                    fontweight='bold',
                    ha='left',
                    va='center',
                    rotation=-90,
                    zorder=4
                )

        # ========================================================
        # LADO DERECHO: PINES 73 - 108
        # ========================================================

        elif 73 <= pin_num <= 108:

            idx = pin_num - 73

            y = -coords[idx]

            x_body = half_body

            lead = patches.Rectangle(
                (
                    x_body,
                    y - lead_width / 2
                ),
                lead_length,
                lead_width,
                facecolor=lead_color,
                edgecolor='#1b1f27',
                lw=0.4,
                zorder=2
            )

            ax.add_patch(lead)

            ax.text(
                x_body - 0.8,
                y,
                str(pin_num),
                color='#d8dee9',
                fontsize=6.5,
                ha='right',
                va='center',
                fontweight='bold',
                zorder=4
            )

            if is_conn:

                ax.text(
                    x_body + lead_length + 0.7,
                    y,
                    label,
                    color=label_color,
                    fontsize=7.5,
                    fontweight='bold',
                    ha='left',
                    va='center',
                    zorder=4
                )

        # ========================================================
        # LADO SUPERIOR: PINES 109 - 144
        # ========================================================

        elif 109 <= pin_num <= 144:

            idx = pin_num - 109

            x = coords[idx]

            y_body = half_body

            lead = patches.Rectangle(
                (
                    x - lead_width / 2,
                    y_body
                ),
                lead_width,
                lead_length,
                facecolor=lead_color,
                edgecolor='#1b1f27',
                lw=0.4,
                zorder=2
            )

            ax.add_patch(lead)

            ax.text(
                x,
                y_body - 0.8,
                str(pin_num),
                color='#d8dee9',
                fontsize=6.5,
                ha='center',
                va='top',
                fontweight='bold',
                rotation=90,
                zorder=4
            )

            if is_conn:

                ax.text(
                    x,
                    y_body + lead_length + 0.7,
                    label,
                    color=label_color,
                    fontsize=7.5,
                    fontweight='bold',
                    ha='left',
                    va='center',
                    rotation=90,
                    zorder=4
                )

    # ============================================================
    # 10. AJUSTAR MÁRGENES
    # ============================================================

    margin = 26.0

    ax.set_xlim(
        -half_body - margin,
        half_body + margin
    )

    ax.set_ylim(
        -half_body - margin,
        half_body + margin
    )

    ax.set_aspect('equal')

    ax.axis('off')

    plt.tight_layout()

    # ============================================================
    # 11. GUARDAR IMAGEN
    # ============================================================

    plt.savefig(
        output_path,
        dpi=200,
        bbox_inches='tight'
    )

    print(
        f"Diagrama guardado exitosamente en: {output_path}"
    )


# ================================================================
# EJECUTAR
# ================================================================

if __name__ == '__main__':

    plot_lqfp144(
        "gowin_ar_lv18e1144pc.csv"
    )
