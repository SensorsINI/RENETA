import matplotlib
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np
import csv

# matplotlib.rcParams['mathtext.fontset'] = 'cm'
# matplotlib.rcParams['font.family'] = 'STIXGeneral'

prop_cycle = plt.rcParams['axes.prop_cycle']
colors = prop_cycle.by_key()['color']

# filename = 'exp_il.csv'
# with open(filename, newline='') as csvfile:
#     spamreader = csv.reader(csvfile, delimiter=',')
#     for row in spamreader:
#         print(', '.join(row))

################################################################################

# num_classes = [20, 25, 30, 35]

# train_acc_lstm = [0.942778668, 0.95242915, 0.942478446, 0.931512932]
# test_acc_lstm  = [0.917276224, 0.890410099, 0.844556097, 0.805203469]

# Retrain 10 epochs LSTM->DeltaLSTM, then retrain 20 epochs for each incremental task
# train_acc_deltalstm = [0.94259556, 0.929227655, 0.939647407, 0.917193917]
# test_acc_deltalstm  = [0.911017269, 0.859888212, 0.822127836, 0.768655294]

# Retrain 20 epochs LSTM->DeltaLSTM, then retrain 20 epochs for each incremental task
# train_acc_deltalstm = [0.943282216, 0.934444098, 0.938875306, 0.896547897]
# test_acc_deltalstm  = [0.912827087, 0.85787854, 0.828602507, 0.770370723]

# Train DeltaLSTM for 20 epochs from scratch, then retrain 20 epochs for each incremental task
# train_acc_deltalstm = [0.937666896, 0.937324821, 0.938939647, 0.900876901]
# test_acc_deltalstm  = [0.912223814, 0.85505244, 0.814099244, 0.772896217]


################################################################################

# num_classes = [20, 23, 26, 29, 32, 35]
# test_acc_lstm  = [[0.917276224, 0.884496684, 0.855849373, 0.81698571, 0.800431879, 0.761364719],
#                   [0.918829796, 0.864603891, 0.847291563, 0.822359958, 0.796032172, 0.77604117],
#                   [0.914541578, 0.880961129, 0.85035019, 0.814655172, 0.79880101, 0.772610312],
#                   [0.90310353, 0.870165746, 0.839421046, 0.80988699, 0.798473742, 0.769417707],
#                   [0.918951132, 0.87270583, 0.840428293, 0.810855167, 0.789977389, 0.778709616]]

# train_acc_35_f1_lstm = [0.94773, 0.94894, 0.94414, 0.94733, 0.94722]
# test_acc_35_f1_lstm = [0.92161, 0.92433, 0.91804, 0.92219, 0.92171]
# train_acc_35_icarl_lstm = [0.920948698, 0.919535963, 0.91866976, 0.92101057, 0.919711266]
test_acc_35_icarl_lstm = [0.892833317, 0.89354808, 0.8859716, 0.891975603, 0.89121319]

# Retrain 20 epochs LSTM->DeltaLSTM, then retrain 20 epochs for each incremental task
# test_acc_deltalstm  = [[0.912827087, 0.875500689, 0.842657552, 0.803397142, 0.770752775, 0.720003812],
#                        [0.912995688, 0.86255991, 0.827196705, 0.807624839, 0.77849866, 0.764366721],
#                        [0.91010661, 0.876993166, 0.83248731, 0.801141659, 0.778397139, 0.767464024],
#                        [0.905235726, 0.858620201, 0.814262641, 0.798140622, 0.78908525, 0.755360717],
#                        [0.91384301, 0.861059925, 0.825373134, 0.798018873, 0.762633433, 0.760173449]]

# train_acc_35_f1_deltalstm = [0.94106, 0.93768, 0.93327, 0.93623, 0.93549]
# test_acc_35_f1_deltalstm = [0.91618, 0.91218, 0.90375, 0.91332, 0.91556]
# train_acc_35_icarl_deltalstm = [0.90588296, 0.900696056, 0.902108791, 0.902160351, 0.90455272]
test_acc_35_icarl_deltalstm = [0.878871629 ,0.870866292 ,0.869293815 ,0.872200515 ,0.874964262]

# y_data = [test_acc_lstm, test_acc_deltalstm]
# y_mean = [np.mean(y, axis=0) for y in y_data]
# y_err = [np.std(y, axis=0) for y in y_data]
# markers = ['s', '^']
# labels = ['LSTM', 'DeltaLSTM(θ=0.1)']

################################################################################
# warmup, batch-1 lr1e-4

# num_classes = [20, 23, 26, 29, 32, 35]
# test_acc_lstm_b32_mean = [0.929171525, 0.896452214, 0.87157376, 0.850783155, 0.831355679, 0.812046126]
# test_acc_lstm_b32_std  = [0.007395284, 0.008154668, 0.014130368, 0.015031872, 0.013415668, 0.005150213]

# test_acc_deltalstm_b32_mean = [0.927685065, 0.89328741, 0.863403891, 0.833172343, 0.820482725, 0.796283236]
# test_acc_deltalstm_b32_std  = [0.005442459, 0.009515508, 0.012352991, 0.008991467, 0.006534417, 0.014481591]

# test_acc_lstm_b1_mean = [0.925078812, 0.895251387, 0.869789088, 0.854882015, 0.832248916, 0.822881921]
# test_acc_lstm_b1_std  = [0.016059396, 0.00835418, 0.012119112, 0.006789945, 0.007478504, 0.004971581]

# test_acc_deltalstm_b1_mean = [0.932466427, 0.886978372, 0.85700689, 0.837123366, 0.815825031, 0.800667111]
# test_acc_deltalstm_b1_std  = [0.006549376, 0.013278061, 0.013392724, 0.007012629, 0.00967834, 0.005976845]



################################################################################
# warmup, batch-32 lr5e-4, batch-1 lr1e-4

num_classes = [20, 23, 26, 29, 32, 35]
test_acc_lstm_b32_mean = [0.929171525, 0.897224563, 0.871683325, 0.851127233, 0.83743654, 0.817182884]
test_acc_lstm_b32_std  = [0.007395284, 0.009030127, 0.012758457, 0.009474757, 0.007513576, 0.011516207]

test_acc_deltalstm_b32_mean = [0.927685065, 0.891804202, 0.863505148, 0.835432423, 0.821488755, 0.803306967]
test_acc_deltalstm_b32_std  = [0.005442459, 0.011110959, 0.014207859, 0.004795494, 0.009846621, 0.01318251]

test_acc_lstm_b1_mean = [0.929171525, 0.895251387, 0.869789088, 0.854882015, 0.832248916, 0.822881921]
test_acc_lstm_b1_std  = [0.016059396, 0.00835418, 0.012119112, 0.006789945, 0.007478504, 0.004971581]

test_acc_deltalstm_b1_mean = [0.927685065, 0.886978372, 0.85700689, 0.837123366, 0.815825031, 0.800667111]
test_acc_deltalstm_b1_std  = [0.006549376, 0.013278061, 0.013392724, 0.007012629, 0.00967834, 0.005976845]

################################################################################
# warmup, batch-32 lr5e-4, batch-1 lr5e-5 epo10

# num_classes = np.arange(20, 35+1)
# test_acc_lstm_b32_mean = [0.929171525, 0.909579294, 0.895021339, 0.885884567, 0.871116794, 0.861726949, 0.852571532, 0.840913905, 0.83254066, 0.822356527, 0.816866477, 0.811901065, 0.799720528, 0.795440511, 0.782704907, 0.77721338]
# test_acc_lstm_b32_std  = [0.007395284, 0.011864572, 0.008062266, 0.010888171, 0.013569195, 0.015046274, 0.01549984, 0.011844964, 0.011123563, 0.010830694, 0.009114209, 0.011866729, 0.006894782, 0.008782432, 0.015122936, 0.009853792]

# test_acc_deltalstm_b32_mean = [0.927685065, 0.908718683, 0.891079546, 0.880275158, 0.870286569, 0.854583816, 0.842611099, 0.826968533, 0.821888187, 0.812173792, 0.805107482, 0.797124526, 0.787512176, 0.781995285, 0.773084227, 0.759592109]
# test_acc_deltalstm_b32_std  = [0.005442459, 0.011044276, 0.008704529, 0.008837058, 0.009539783, 0.012747984, 0.012940241, 0.007681303, 0.005949082, 0.009022437, 0.007086166, 0.008983396, 0.012935636, 0.006259105, 0.005559958, 0.004974138]

# test_acc_lstm_b1_mean = [0.929171525, 0.913905966, 0.901366646, 0.891225161, 0.876714552, 0.863285628, 0.854222719, 0.843032941, 0.830263571, 0.819479767, 0.81403689, 0.803041899, 0.79301166, 0.788321219, 0.774454706, 0.766263223]
# test_acc_lstm_b1_std  = [0.007395284, 0.008951272, 0.007334889, 0.005618797, 0.013296221, 0.010952761, 0.012679763, 0.010772209, 0.011769539, 0.010525787, 0.009581463, 0.012132427, 0.012759397, 0.009202231, 0.010408778, 0.008192227]

# test_acc_deltalstm_b1_mean = [0.927685065, 0.911636738, 0.895771717, 0.882862869, 0.873026973, 0.858537549, 0.842854688, 0.828321205, 0.816899493, 0.806325861, 0.800012805, 0.791578962, 0.777600193, 0.769365241, 0.760251982, 0.748470409]
# test_acc_deltalstm_b1_std  = [0.005442459, 0.011322993, 0.007282035, 0.008238029, 0.008985716, 0.01079149, 0.012956512, 0.009522478, 0.00944112, 0.010828744, 0.009558876, 0.006045792, 0.003847403, 0.00712359, 0.005840343, 0.003448945]



################################################################################
# Plot

y_mean = [test_acc_lstm_b32_mean, test_acc_deltalstm_b32_mean, test_acc_lstm_b1_mean, test_acc_deltalstm_b1_mean]
y_err = [test_acc_lstm_b32_std, test_acc_deltalstm_b32_std, test_acc_lstm_b1_std, test_acc_deltalstm_b1_std]
markers = ['s', '^', 's', '^']
labels = ['LSTM Batch-32', 'DeltaLSTM(θ=0.1) Batch-32', 'LSTM Batch-1', 'DeltaLSTM(θ=0.1) Batch-32']
line_colors = [colors[x] for x in [0, 0, 1, 1]]
line_styles = ['-', '--', '-', '--']
# labels = ['LSTM b32', 'DeltaLSTM(θ=0.1) b32', 'LSTM b1', 'DeltaLSTM(θ=0.1) b1']
x_ticks = num_classes
num_tasks = len(x_ticks)

# plot
fig, ax = plt.subplots(figsize=(5.33, 4))

base_lstm_mean = np.mean(test_acc_35_icarl_lstm)
base_lstm_std = np.std(test_acc_35_icarl_lstm)
ax.axhline(y=base_lstm_mean, color=colors[2], linestyle='-', linewidth=1.5)
ax.errorbar(num_tasks-1, base_lstm_mean, yerr=base_lstm_std,
                color=colors[2], linestyle='-', linewidth=1.5, capsize=2, elinewidth=1.0)
base_deltalstm_mean = np.mean(test_acc_35_icarl_deltalstm)
base_deltalstm_std = np.std(test_acc_35_icarl_deltalstm)
ax.axhline(y=np.mean(base_deltalstm_mean), color=colors[2], linestyle='--', linewidth=1.5)
ax.errorbar(num_tasks-1, base_deltalstm_mean, yerr=base_deltalstm_std,
                color=colors[2], linestyle='-', linewidth=1.5, capsize=2, elinewidth=1.0)

for i, (y_i, yerr_i) in enumerate(zip(y_mean, y_err)):
    y_i, yerr_i = np.array(y_i), np.array(yerr_i)
    x = np.arange(num_tasks)
    ax.errorbar(x, y_i, yerr=yerr_i,
                color=line_colors[i], linestyle=line_styles[i], linewidth=2.0, capsize=2, elinewidth=1.0,
                label=labels[i])
    # ax.plot(x, y_i,
    #         color=line_colors[i], linestyle=line_styles[i], linewidth=2.0,
    #         marker=markers[i], markersize=4,
    #         label=labels[i])
    # ax.fill_between(x, y_i-yerr_i, y_i+yerr_i, color=line_colors[i], alpha=0.1)

# ax.set_title('iCaRL Test Accuracy on GSC Dataset')
ax.set_ylabel('Accuracy')
ax.set_xlabel('Number of Classes')
ax.yaxis.set_major_formatter(mtick.PercentFormatter(1.0))
# ax.set_ylim(0.60, 1.00)
ax.set_xticks(np.arange(num_tasks), x_ticks)
ax.legend(loc='lower left')
ax.grid(True, color='#ebebeb')

plt.tight_layout()

# plt.savefig('plot/exp_il.png')
# plt.savefig('plot/exp_gscd_il_20+3x5.pdf', bbox_inches='tight')
# plt.savefig('plot/exp_gscd_il_20+1x15.pdf', bbox_inches='tight')
plt.savefig('plot/exp_gscd_il_20+3x5_errbar.pdf', bbox_inches='tight')
# plt.savefig('plot/exp_gscd_il_20+1x15_errbar.pdf', bbox_inches='tight')

plt.show()
