function [u]=two_dir_alloc_df4(B,v_T, v_D,umin,umax)
% (c) mengchaoheng
% Last edited 2019-11
v=v_T+v_D;
[uv,z_uv,~]  = allocator_dir_LPwrap_4(B,v,umin,umax); % wls_alloc_mch(v,u);% 先计算合力矩所需舵量
if(z_uv>=1) % 若舵量可以满足则直接满足
    u=uv;
else  % 否则再计算扰动所需
     [uv1,z_uv1,~]= allocator_dir_LPwrap_4(B,v_T,umin,umax); % wls_alloc_mch(v1,u);
    if(z_uv1>=1)  % 若扰动可满足，合力矩不能满足，则进行两次分配
        umin1=umin-uv1;
        umax1=umax-uv1;
        uv2 = allocator_dir_LPwrap_4(B,v_D,umin1,umax1);
        u=uv1+uv2;
    else  % 扰动也不能满足，则直接按照合力矩进行分配
        u=uv;
    end
end
