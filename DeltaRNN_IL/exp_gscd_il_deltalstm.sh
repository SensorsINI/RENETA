# Retrain DeltaLSTM from LSTM
# python main.py --dataset gscdv2 \
#     --il_load_pretrain 1 \
#     --step retrain --epochs_retrain 20 --batch_size 32 \
#     --model_pretrain 'cla-rnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 0 --num_new_classes 20 --num_exemplars 2000

# Train DeltaLSTM from scratch
# python main.py --dataset gscdv2 \
#     --step pretrain --epochs_pretrain 20 --batch_size 32 \
#     --model_pretrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 0 --num_new_classes 20 --num_exemplars 2000

# python main.py --dataset gscdv2 \
#     --il_load_pretrain 1 \
#     --step retrain --epochs_retrain 20 --batch_size 32 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 20 --num_new_classes 5 --num_exemplars 2000

# python main.py --dataset gscdv2 \
#     --step retrain --epochs_retrain 20 --batch_size 32 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 25 --num_new_classes 5 --num_exemplars 2000

# python main.py --dataset gscdv2 \
#     --step retrain --epochs_retrain 20 --batch_size 32 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 30 --num_new_classes 5 --num_exemplars 2000





# Retrain DeltaLSTM from LSTM
python main.py --dataset gscdv2 --feat_folder '1' \
    --il_load_pretrain 1 \
    --step retrain --epochs_retrain 20 --batch_size 32 \
    --model_pretrain 'cla-rnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 1 --save_best_model 0 \
    --il_mode 1 --num_learned_classes 0 --num_new_classes 20 --num_exemplars 2000

python main.py --dataset gscdv2 --feat_folder '1' \
    --step retrain --epochs_retrain 20 --batch_size 32 \
    --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 1 --save_best_model 0 \
    --il_mode 1 --num_learned_classes 20 --num_new_classes 3 --num_exemplars 2000

python main.py --dataset gscdv2 --feat_folder '1' \
    --step retrain --epochs_retrain 20 --batch_size 32 \
    --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 1 --save_best_model 0 \
    --il_mode 1 --num_learned_classes 23 --num_new_classes 3 --num_exemplars 2000

python main.py --dataset gscdv2 --feat_folder '1' \
    --step retrain --epochs_retrain 20 --batch_size 32 \
    --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 1 --save_best_model 0 \
    --il_mode 1 --num_learned_classes 26 --num_new_classes 3 --num_exemplars 2000

python main.py --dataset gscdv2 --feat_folder '1' \
    --step retrain --epochs_retrain 20 --batch_size 32 \
    --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 1 --save_best_model 0 \
    --il_mode 1 --num_learned_classes 29 --num_new_classes 3 --num_exemplars 2000

python main.py --dataset gscdv2 --feat_folder '1' \
    --step retrain --epochs_retrain 20 --batch_size 32 \
    --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
    --thx 0.1 --thh 0.1 \
    --eval_val 1 --eval_test 1 --lr_schedule 1 \
    --write_log 1 --save_best_model 0 \
    --il_mode 1 --num_learned_classes 32 --num_new_classes 3 --num_exemplars 2000







# Batch-1

# Retrain DeltaLSTM from LSTM
# python main.py --dataset gscdv2 --feat_folder '5' \
#     --il_load_pretrain 1 \
#     --step retrain --epochs_retrain 20 --batch_size 32 \
#     --model_pretrain 'cla-rnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 0 --num_new_classes 20 --num_exemplars 2000

# python main.py --dataset gscdv2 --feat_folder '5' \
#     --step retrain --epochs_retrain 10 --batch_size 1 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 20 --num_new_classes 3 --num_exemplars 2000

# python main.py --dataset gscdv2 --feat_folder '5' \
#     --step retrain --epochs_retrain 10 --batch_size 1 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 23 --num_new_classes 3 --num_exemplars 2000

# python main.py --dataset gscdv2 --feat_folder '5' \
#     --step retrain --epochs_retrain 10 --batch_size 1 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 26 --num_new_classes 3 --num_exemplars 2000

# python main.py --dataset gscdv2 --feat_folder '5' \
#     --step retrain --epochs_retrain 10 --batch_size 1 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 29 --num_new_classes 3 --num_exemplars 2000

# python main.py --dataset gscdv2 --feat_folder '5' \
#     --step retrain --epochs_retrain 10 --batch_size 1 \
#     --model_pretrain 'cla-deltarnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 1 --save_best_model 0 \
#     --il_mode 1 --num_learned_classes 32 --num_new_classes 3 --num_exemplars 2000








# python main.py --dataset gscdv2 --feat_folder '5' \
#     --step pretrain --epochs_pretrain 20 --batch_size 32 \
#     --model_pretrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 0 --save_best_model 0 --il_save_model 0 \
#     --il_mode 1 --num_learned_classes 0 --num_new_classes 35 --num_exemplars 2000



# python main.py --dataset gscdv2 --feat_folder '5' \
#     --il_load_pretrain 1 \
#     --step retrain --epochs_retrain 1 --batch_size 32 \
#     --model_pretrain 'cla-rnn' --model_retrain 'cla-deltarnn' --rnn_type 'LSTM3' --rnn_size 128 \
#     --thx 0.1 --thh 0.1 \
#     --eval_val 1 --eval_test 1 --lr_schedule 1 \
#     --write_log 0 --save_best_model 0 --il_save_model 0 \
#     --il_mode 1 --num_learned_classes 0 --num_new_classes 20 --num_exemplars 2000
