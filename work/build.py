import os
import shutil
from siliconcompiler import ASIC, Design
from siliconcompiler.targets import skywater130_demo

def make_dir(target):
    # Directory backup logic
    bk_target = f"{target}.bk"
    if os.path.isdir(bk_target):
        shutil.rmtree(bk_target)
    if os.path.isdir(target):
        os.rename(target, bk_target)
    os.makedirs(target, exist_ok=True)

def main():
    # 1. 前処理
    make_dir("build")

    # 2. 設計（Design）の定義
    design = Design('riscv32')
    design.set_topmodule('riscv32', fileset='rtl')
    
    # srcディレクトリからファイルを自動登録
    rtl_dir = 'src'
    for f in os.listdir(rtl_dir):
        if f.endswith(('.sv', '.svh')):
            file_path = os.path.join(rtl_dir, f)
            design.add_file(file_path, fileset='rtl')
            print(f"Registered: {file_path}")

    # インクルードパスの設定（.svh読み込み用）
    design.add_idir(rtl_dir, fileset='rtl')

    # 3. プロジェクト（ASIC）の作成
    project = ASIC(design)
    project.add_fileset(['rtl'])

    # 4. ターゲット設定
    skywater130_demo(project)

    # 5. タイミング制約（最新の階層パス）
    # [constraint, timing, <name>, period]
    project.set('constraint', 'timing', 'clk', 'period', 20.0)
    project.set('constraint', 'timing', 'clk', 'pin', 'clk')

    project.set("constraint", "period", 20.0, clkname="clk")

    # 6. 実行
    print("Launching latest SiliconCompiler flow...")
    project.run()
    project.summary()

if __name__ == '__main__':
    main()