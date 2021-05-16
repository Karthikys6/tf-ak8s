module "dev_env" {
    source       = "./src"
    env          = "dev"
}

module "qa_env" {
    source       = "./src"
    env          = "qa"
}

module "prod_env" {
    source       = "./src"
    env          = "prod"
}

