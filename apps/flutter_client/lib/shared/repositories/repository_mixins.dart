import "package:polyphony_flutter_client/shared/result/result.dart";

mixin RepositoryGetOne<TEntity, TQuery> {
  Future<Result<TEntity>> getOne({required TQuery query});
}

mixin RepositoryGetMany<TEntity, TQuery> {
  Future<Result<Iterable<TEntity>>> getMany({required TQuery query});
}

mixin RepositoryCreateOne<TEntity, TCommand> {
  Future<Result<TEntity>> createOne({required TCommand command});
}

mixin RepositoryCreateMany<TEntity, TCommand> {
  Future<Result<List<TEntity>>> createMany({required TCommand command});
}

mixin RepositoryDeleteOne<TCommand> {
  Future<Result<void>> deleteOne({required TCommand command});
}

mixin RepositoryDeleteMany<TCommand> {
  Future<Result<void>> deleteMany({required TCommand command});
}

mixin RepositoryUpdateOne<TResult, TCommand> {
  Future<Result<TResult>> updateOne({required TCommand command});
}

mixin RepositoryUpdateMany<TResult, TCommand> {
  Future<Result<Iterable<TResult>>> updateMany({required TCommand command});
}
