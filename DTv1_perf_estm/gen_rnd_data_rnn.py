# Generate random data for DTv1 performance estimation

import numpy as np
# import pickle



################################################################
# Constants

# HW parameters
NUM_PE = 16
MAX_N = 256
MAX_M = 256
WEIGHT_BW = ACT_BW = ACC_BW = 16
LHA_BW = np.ceil(np.log2(MAX_N/NUM_PE*MAX_M)).astype(int)   # 12
LHP_BW = np.ceil(np.log2(NUM_PE)).astype(int)               # 4
NZN_BW = np.ceil(np.log2(MAX_N)).astype(int)                # 8

INT_LOW = -(2**3)   # Min integer (inclusive) for random number generator
INT_HIGH = (2**3)-1 # Max integer (exclusive) for random number generator

Np = NUM_PE
Nl = 1              # Number of layers
Nh = [256, 256]
Nx = [0] + Nh[:-1]
Sp_x = [0.5, 0.8, 0.9]        # Sparsity of Δx each sample
Sp_h = [0.5, 0.8, 0.9]        # Sparsity of Δh

Nb = 1              # Batch size
Ns = 3              # Number of samples to generate
Nt = [256] * Ns

dir = 'C:\Workspace\Vivado\dtv1.0_perf_estm\dat'
# dir += f'\I{Nh[0]}_H{Nh[1]}_T{Nt[0]}_P{NUM_PE}'

np.random.seed(0)
np.set_printoptions(threshold=1024, linewidth=256)
rng = np.random.default_rng()

# Pytorch LSTM default sizes:
# Wx: (Nh*1, Nx)
# Wh: (Nh*1, Nh)
# x: (Nt, Nb, Nx)



################################################################
# Utility functions

# Pad zeros to the array 'x' so that the shape on its 'axis' is a multile of 'div'
# x: array to pad
# div: divisor
def pad_zero(x, div, axis):
    rmd = x.shape[axis] % div
    if (rmd > 0):
        p_width_l = [[0, 0]] * x.ndim
        p_width_l[axis] = [0, div - rmd]
        x = np.pad(x, p_width_l, 'constant', constant_values=0)
    return x



################################################################
# Main

l = 1

for s in range(0, Ns):
    
    ################################
    # x_del[l]      (Nt[s], Nx[l])
    
    # x = np.random.randint(INT_LOW, INT_HIGH, size=(Nt[s], Nx[l]), dtype=np.int16)
    # x_msk = np.random.rand(Nt[s], Nx[l]) >= Sp_x[s]
    # x[~x_msk] = 0
    # x_up = x
    # print('x_del =\n', x)
    # x_nzi_row, x_nzi_col = x.nonzero()
    # x_nzn_total = x_nzi_row.shape[0]
    
    x = np.random.randint(INT_LOW, INT_HIGH, size=(Nt[s], Nx[l]), dtype=np.int16)
    x[x>=0] += 1    # Remove existing zeros
    x_nzn_total = np.ceil(Nx[l] * Nx[l] * (1-Sp_x[s])).astype(int)
    xy = np.mgrid[0:Nt[s], 0:Nx[l]].reshape(2,-1).T
    n_trial = 0
    while True:
        xy = rng.permutation(xy)
        xy_selected = xy[:x_nzn_total]
        x_nzi_row = xy_selected[:, 0]
        x_nzi_col = xy_selected[:, 1]
        if np.unique(x_nzi_row).shape[0] == Nt[s]: break
        n_trial += 1
        if n_trial > 1000: raise Exception("Could not find a valid permutation of x!")
    x_msk = np.zeros_like(x, dtype=np.bool)
    x_msk[x_nzi_row, x_nzi_col] = 1
    x[~x_msk] = 0
    x_up = x
    x_nzi_row, x_nzi_col = x.nonzero()
    
    x_nzn = [np.sum(x_nzi_row==ti) for ti in range(Nt[s])]  # List of NZN at each time step
    x_nzn = np.array(x_nzn)
    
    x_nzn_cumsum = np.cumsum(x_nzn)
    x_head_idx = np.append([0], x_nzn_cumsum[:-1])
    x_lha, x_lhp = np.divmod(x_head_idx, np.array([NUM_PE]))
    
    split_indices = x_nzn_cumsum[:-1]
    x_nzi_all = x_nzi_col                       # NZIs in all timesteps, 1-D array
    x_nzv_all = x[x_nzi_row, x_nzi_col]         # NZVs in all timesteps, 1-D array
    x_nzil = np.split(x_nzi_all, split_indices) # List of NZI-array at each timestep, len==Nt[s]
    x_nzvl = np.split(x_nzv_all, split_indices) # List of NZV-array at each timestep, len==Nt[s]
    for ti, (nzil, nzvl, nzn, lha, lhp) in enumerate(zip(x_nzil, x_nzvl, x_nzn, x_lha, x_lhp)):
        print(f'\nt={ti}:\t{nzil}\n\t{nzvl}\n\t({lha}, {lhp}) {nzn}')
    print(f'\nTotal non-zeros = {x_nzn_total}\n')
    
    with open(f"{dir}\\x_del_nzp_l{l}_s{s}.dat", 'wb') as fo_nzp:
        # fo_nzp.write(x_nzn_total.to_bytes(2, byteorder='big'))
        fo_nzp.write(Nt[s].to_bytes(2, byteorder='big'))
        # x_lha.astype('>i2').tofile(fo_nzp)
        # x_lhp.astype('>i2').tofile(fo_nzp)
        # x_nzn.astype('>i2').tofile(fo_nzp)
        x_spm = x_lha.astype('>i4') << (LHP_BW + NZN_BW) | \
                x_lhp.astype('>i4') << (NZN_BW)          | \
                x_nzn.astype('>i4')
        x_spm.astype('>i4').tofile(fo_nzp)
    
    # Not padded
    with open(f"{dir}\\x_del_nzl_l{l}_s{s}.dat", 'wb') as fo_nzl:
        for x_nzil_ti in x_nzil:
            x_nzil_ti.astype('>i2').tofile(fo_nzl)
        for x_nzvl_ti in x_nzvl:
            x_nzvl_ti.astype('>i2').tofile(fo_nzl)

    # # Pad last timestep for VXV_SP
    # x_nzil[-1] = np.arange(0, Nx[l], dtype=np.int16)
    # x_nzvl[-1] = x[-1, :]
    # x_nzn[-1] = Nx[l]
    # x_nzn_total = np.sum(x_nzn)
    # print(f'Padded:\nt={Nt[s]-1}:\t{x_nzil[-1]}\n\t{x_nzvl[-1]}\n\t({x_lha[-1]}, {x_lhp[-1]}) {x_nzn[-1]}')
    # print(f'\nTotal non-zeros = {x_nzn_total}\n')

    # # Padded
    # with open(f"{dir}\\x_del_nzp_p_l{l}_s{s}.dat", 'wb') as fo_nzp:
    #     fo_nzp.write(Nt[s].to_bytes(2, byteorder='big'))
    #     x_spm = x_lha.astype('>i4') << (LHP_BW + NZN_BW) | \
    #             x_lhp.astype('>i4') << (NZN_BW)          | \
    #             x_nzn.astype('>i4')
    #     x_spm.astype('>i4').tofile(fo_nzp)
    
    # # Padded
    # with open(f"{dir}\\x_del_nzl_p_l{l}_s{s}.dat", 'wb') as fo_nzl:
    #     for x_nzil_ti in x_nzil:
    #         x_nzil_ti.astype('>i2').tofile(fo_nzl)
    #     for x_nzvl_ti in x_nzvl:
    #         x_nzvl_ti.astype('>i2').tofile(fo_nzl)

    ################################
    # Wx[l]         (Nh[l]*1, Nx[l])
    if (s==0):
        Wx = np.random.randint(INT_LOW, INT_HIGH, size=(Nh[l]*1, Nx[l]), dtype=np.int16)
        Wx_up = Wx
        print(f'Wx =\n{Wx}\n')
        Wx = pad_zero(Wx, NUM_PE, axis=0)
        Wx_dram = Wx.reshape(-1, NUM_PE, Wx.shape[1]).swapaxes(1, 2)    # (Nh*1//Np, Nx, Np)
        # Wx_dram = Wx_dram.reshape(-1, NUM_PE)
        # print('Wx_dram =\n', Wx_dram)
        with open(f"{dir}\\Wx_l{l}.dat", 'wb') as fo_Wx:
            Wx_dram.astype('>i2').tofile(fo_Wx)

    ################################
    # Mx[l]         (Nt[s], Nh[l]*1)
    Mx = np.matmul(x_up, Wx_up.T)
    Mx_up = Mx
    # print(f'Mx =\n{Mx}\n')
    print(f'Mx =\n{Mx.reshape((Nt[s], Nh[l]*1//Np, Np))}\n')
    Mx = pad_zero(Mx, NUM_PE, axis=1)
    Mx_dram = Mx.reshape(Mx.shape[0], -1, NUM_PE).swapaxes(0, 1)
    with open(f"{dir}\\Mx_l{l}_s{s}.dat", 'wb') as fo:
        Mx_dram.astype('>i2').tofile(fo)

    ################################
    # dL_dM[l]      (Nt[s], Nh[l]*1)
    dL_dM = np.random.randint(INT_LOW, INT_HIGH, size=(Nt[s], Nh[l]*1), dtype=np.int16)
    dL_dM_up = dL_dM
    # print(f'dL_dM =\n{dL_dM}\n')
    print(f'dL_dM =\n{dL_dM.reshape((Nt[s], Nh[l]*1//Np, Np))}\n')
    dL_dM = pad_zero(dL_dM, NUM_PE, axis=1)
    dL_dM_dram = dL_dM.reshape(dL_dM.shape[0], -1, NUM_PE).swapaxes(0, 1)
    with open(f"{dir}\\dL_dMx_l{l}_s{s}.dat", 'wb') as fo:
        dL_dM_dram.astype('>i2').tofile(fo)

    ################################
    # dL_ddx[l]     (Nt[s], Nx[l])
    dL_ddx = np.matmul(dL_dM_up, Wx_up)
    dL_ddx[~x_msk] = 0
    dL_ddx_up = dL_ddx
    print(f'dL_ddx =\n{dL_ddx}\n')
    dL_ddx = pad_zero(dL_ddx, NUM_PE, axis=1)
    dL_ddx_dram = dL_ddx.reshape(dL_ddx.shape[0], -1, NUM_PE).swapaxes(0, 1)
    with open(f"{dir}\\dL_ddx_l{l}_s{s}.dat", 'wb') as fo:
        dL_ddx_dram.astype('>i2').tofile(fo)

    ################################
    # dL_dWx[l]     (Nh[l]*1, Nx[l])
    dL_dWx = np.matmul(dL_dM_up.T, x_up)
    dL_dWx_up = dL_dWx
    print(f'dL_dWx =\n{dL_dWx}\n')
    # # Add bias column
    # w = np.insert(w, w.shape[1], b, axis=1)
    dL_dWx = pad_zero(dL_dWx, NUM_PE, axis=0)
    dL_dWx_dram = dL_dWx.reshape(-1, NUM_PE, dL_dWx.shape[1]).swapaxes(1, 2)
    with open(f"{dir}\\dL_dWx_l{l}_s{s}.dat", 'wb') as fo:
        dL_dWx_dram.astype('>i2').tofile(fo)
