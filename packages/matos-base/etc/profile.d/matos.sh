# matOS : outils matOS dans le PATH
case ":$PATH:" in
    *:/opt/matos/bin:*) ;;
    *) PATH="$PATH:/opt/matos/bin" ;;
esac
export PATH
