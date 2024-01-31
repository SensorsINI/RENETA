python main.py --dataset gscdv2 \
    --step pretrain --epochs_pretrain 40 --batch_size 32\
    --model_pretrain 'cla-deltarnn' --rnn_type 'LSTM' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 0 --save_best_model 0 \
    --il_mode 0 --num_learned_classes 0 --num_new_classes 35

